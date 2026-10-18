from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from kubernetes import client, config
from kubernetes.stream import stream
import asyncio
import uuid
import os
import subprocess
import yaml

app = FastAPI()

# Allow CORS for frontend development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files for the frontend
app.mount("/static", StaticFiles(directory="static"), name="static")

DEFAULT_NAMESPACE = os.getenv("NAMESPACE", "lang-app")


def normalize_language(language: str) -> str:
    """Map frontend language names to backend runtime names."""
    mapping = {
        "python": "python",
        "javascript": "node",
        "js": "node",
        "node": "node",
        "go": "go",
        "golang": "go",
    }
    normalized = mapping.get(language.lower())
    if not normalized:
        raise ValueError(f"Unsupported language: {language}")
    return normalized


try:
    config.load_incluster_config()
except config.config_exception.ConfigException:
    print("Falling back to local kube config...")
    config.load_kube_config()


class CodeExecutionRequest(BaseModel):
    code: str
    language: str


@app.get("/")
async def root():
    return FileResponse("static/index.html")


@app.post("/execute")
async def execute_code(request: CodeExecutionRequest):
    """Handle code execution requests from the UI."""
    try:
        language = normalize_language(request.language)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    job_id = str(uuid.uuid4())
    temp_dir = f"/tmp/{job_id}"
    os.makedirs(temp_dir, exist_ok=True)

    filename = get_filename(language)
    filepath = os.path.join(temp_dir, filename)
    with open(filepath, "w") as f:
        f.write(request.code)

    create_configmap(job_id, [filepath], namespace=DEFAULT_NAMESPACE)
    job_yaml = generate_job_yaml(language, [filename], job_id)
    create_k8s_job(job_yaml, job_id, namespace=DEFAULT_NAMESPACE)

    return {"job_id": job_id, "status": "submitted"}


@app.websocket("/ws/{job_id}")
async def websocket_terminal(websocket: WebSocket, job_id: str):
    await websocket.accept()

    # Wait for pod to be ready (polling)
    pod_name = None
    for _ in range(60):  # Retry for ~30 seconds
        pod_name = await asyncio.to_thread(get_pod_name, job_id)
        if pod_name:
            break
        await asyncio.sleep(0.5)

    if not pod_name:
        await websocket.send_text("Error: Pod not ready or doesn't exist yet.")
        await websocket.close(code=1011)
        return

    # Wait for the container to be ready before attempting exec
    v1 = client.CoreV1Api()
    for _ in range(60):
        pod = await asyncio.to_thread(
            v1.read_namespaced_pod, pod_name, DEFAULT_NAMESPACE
        )
        if pod.status.phase == "Running" and all(
            c.ready for c in (pod.status.container_statuses or [])
        ):
            break
        await asyncio.sleep(0.5)
    else:
        await websocket.send_text("Error: Pod container is not ready.")
        await websocket.close(code=1011)
        return

    resp = None
    try:
        # Read the run command from the Job annotation
        batch_v1 = client.BatchV1Api()
        job = await asyncio.to_thread(
            batch_v1.read_namespaced_job,
            f"user-code-job-{job_id}",
            DEFAULT_NAMESPACE,
        )
        annotations = job.metadata.annotations or {}
        run_command = annotations.get("run-command", "echo 'No run command found'")

        v1 = client.CoreV1Api()
        resp = stream(
            v1.connect_get_namespaced_pod_exec,
            pod_name,
            DEFAULT_NAMESPACE,
            command=["/bin/sh"],
            stderr=True,
            stdin=True,
            stdout=True,
            tty=True,
            _preload_content=False,
        )

        # Give the shell a moment to start, then run the user's code
        await asyncio.sleep(0.5)
        await asyncio.to_thread(resp.write_stdin, run_command + "\n")

        async def read_stdout():
            while await asyncio.to_thread(resp.is_open):
                await asyncio.to_thread(resp.update, timeout=1)
                if await asyncio.to_thread(resp.peek_stdout):
                    out = await asyncio.to_thread(resp.read_stdout)
                    await websocket.send_text(out)
                if await asyncio.to_thread(resp.peek_stderr):
                    err = await asyncio.to_thread(resp.read_stderr)
                    await websocket.send_text(err)

        async def write_stdin():
            try:
                while True:
                    try:
                        msg = await websocket.receive_text()
                        if msg.strip().lower() in {"exit", "quit"}:
                            await asyncio.to_thread(resp.write_stdin, "exit\n")
                            break
                        await asyncio.to_thread(resp.write_stdin, msg + "\n")
                    except WebSocketDisconnect:
                        break
                    except Exception as e:
                        await websocket.send_text(f"Error: {str(e)}")
                        break
            finally:
                if resp:
                    await asyncio.to_thread(resp.close)

        await asyncio.gather(read_stdout(), write_stdin())

    except Exception as e:
        import traceback
        error_msg = f"Error during WebSocket session: {str(e)}\n{traceback.format_exc()}"
        print(error_msg, flush=True)
        await websocket.send_text(f"Error during WebSocket session: {str(e)}")
    finally:
        if resp:
            await asyncio.to_thread(resp.close)

        # Clean up the Job and its ConfigMap once the session ends so the
        # pod does not keep running as a leftover sleeper.
        try:
            batch_v1 = client.BatchV1Api()
            await asyncio.to_thread(
                batch_v1.delete_namespaced_job,
                f"user-code-job-{job_id}",
                DEFAULT_NAMESPACE,
                body=client.V1DeleteOptions(propagation_policy="Foreground"),
            )
            v1 = client.CoreV1Api()
            await asyncio.to_thread(
                v1.delete_namespaced_config_map,
                f"user-code-configmap-{job_id}",
                DEFAULT_NAMESPACE,
                body=client.V1DeleteOptions(),
            )
            print(f"Cleaned up Job/ConfigMap for session {job_id}", flush=True)
        except Exception as cleanup_err:
            print(
                f"Cleanup warning for session {job_id}: {cleanup_err}",
                flush=True,
            )

        try:
            await websocket.close()
        except Exception:
            pass


def get_filename(language: str) -> str:
    """Get appropriate filename based on normalized language."""
    extensions = {
        "python": "main.py",
        "node": "main.js",
        "go": "main.go",
    }
    return extensions.get(language, "code.txt")


def get_container_image(language: str) -> str:
    """Return the runner image for a normalized language."""
    images = {
        "python": "python:3.12-slim",
        "node": "node:16",
        "go": "golang:1.19",
    }
    return images[language]


def get_run_command(language: str, file_paths: list) -> str:
    """Return the shell command to execute the submitted code."""
    if language == "python":
        return "python /app/code/main.py"
    elif language == "node":
        return "node /app/code/main.js"
    elif language == "go":
        go_files = " ".join([f"/app/code/{os.path.basename(file)}" for file in file_paths])
        return f"cd /app/code && go run {go_files}"
    else:
        raise ValueError(f"Unsupported language: {language}")


def generate_job_yaml(language: str, file_paths: list, job_id: str):
    # The pod stays alive so the WebSocket can attach and run the code
    # in an interactive shell. The language label and run-command annotation
    # tell the WebSocket which runtime command to issue.
    run_command = get_run_command(language, file_paths)
    job_body = {
        "apiVersion": "batch/v1",
        "kind": "Job",
        "metadata": {
            "name": f"user-code-job-{job_id}",
            "labels": {"language": language, "managed-by": "langapp-runner"},
            "annotations": {"run-command": run_command},
        },
        "spec": {
            "ttlSecondsAfterFinished": 60,
            "template": {
                "metadata": {"labels": {"language": language, "managed-by": "langapp-runner"}},
                "spec": {
                    "terminationGracePeriodSeconds": 5,
                    "containers": [
                        {
                            "name": "user-code",
                            "image": get_container_image(language),
                            "command": ["sleep", "3600"],
                            "volumeMounts": [{"name": "code-volume", "mountPath": "/app/code"}],
                        }
                    ],
                    "restartPolicy": "Never",
                    "volumes": [
                        {
                            "name": "code-volume",
                            "configMap": {"name": f"user-code-configmap-{job_id}"},
                        }
                    ],
                },
            },
        },
    }
    return yaml.dump(job_body, default_flow_style=False)


def create_k8s_job(job_yaml: str, job_id: str, namespace: str = "lang-app"):
    job_file = "/tmp/job.yaml"
    with open(job_file, "w") as f:
        f.write(job_yaml)

    subprocess.run(["kubectl", "apply", "-f", job_file, "-n", namespace], check=True)

    job_name = f"user-code-job-{job_id}"
    configmap_name = f"user-code-configmap-{job_id}"
    print(f"Job created: {job_name}")
    print(f"ConfigMap used: {configmap_name}")

    try:
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", namespace, "-l", f"job-name={job_name}", "-o", "jsonpath={.items[0].metadata.name}"],
            capture_output=True,
            text=True,
            check=True
        )
        pod_name = result.stdout.strip()
        if pod_name:
            print(f"Associated Pod: {pod_name}")
    except subprocess.CalledProcessError as e:
        print(f"Failed to retrieve pod: {e.stderr}")


def create_configmap(job_id: str, file_paths: list, namespace: str = DEFAULT_NAMESPACE):
    configmap_name = f"user-code-configmap-{job_id}"
    config_map_data = {}

    for file_path in file_paths:
        with open(file_path, "r") as f:
            config_map_data[os.path.basename(file_path)] = f.read()

    config_map_body = {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {"name": configmap_name, "namespace": namespace},
        "data": config_map_data
    }

    configmap_yaml = yaml.dump(config_map_body, default_flow_style=False)
    configmap_file = "/tmp/configmap.yaml"
    with open(configmap_file, "w") as f:
        f.write(configmap_yaml)

    subprocess.run(["kubectl", "apply", "-f", configmap_file, "-n", namespace], check=True)


@app.get("/logs/{job_id}")
def get_job_logs(job_id: str):
    pod_name = get_pod_name(job_id)
    if pod_name is None:
        return {"error": "Pod not found for job id."}

    logs = subprocess.check_output(["kubectl", "logs", "-f", pod_name, "-n", DEFAULT_NAMESPACE], stderr=subprocess.STDOUT)
    return {"logs": logs.decode("utf-8")}


def get_pod_name(job_id: str):
    v1 = client.CoreV1Api()
    pods = v1.list_namespaced_pod(
        namespace=DEFAULT_NAMESPACE,
        label_selector=f"job-name=user-code-job-{job_id}",
    )
    if pods.items:
        return pods.items[0].metadata.name
    return None
