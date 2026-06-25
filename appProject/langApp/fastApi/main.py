from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from kubernetes import client, config
from kubernetes.stream import stream
import asyncio
import uuid
import os
import subprocess
import shutil
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

# # Load Kubernetes config
# config.load_incluster_config()

try:
    config.load_incluster_config()
except config.config_exception.ConfigException:
    print("Falling back to local kube config...")
    config.load_kube_config()

# Model for code execution request
class CodeExecutionRequest(BaseModel):
    code: str
    language: str
    input: str = ""

@app.get("/")
async def root():
    return {"message": "Code Execution API is running"}

@app.post("/execute")
async def execute_code(request: CodeExecutionRequest):
    """Handle code execution requests from the UI"""
    job_id = str(uuid.uuid4())
    temp_dir = f"/tmp/{job_id}"
    os.makedirs(temp_dir, exist_ok=True)
    
    # Save code to a file
    filename = get_filename(request.language)
    filepath = os.path.join(temp_dir, filename)
    with open(filepath, "w") as f:
        f.write(request.code)
    
    # Create Kubernetes resources
    create_configmap(job_id, [filepath])
    job_yaml = generate_job_yaml(request.language, [filename], job_id)
    create_k8s_job(job_yaml, job_id)
    
    return {"job_id": job_id, "status": "submitted"}

# @app.websocket("/ws/{job_id}")
# async def websocket_terminal(websocket: WebSocket, job_id: str):
#     """WebSocket endpoint for live terminal interaction"""
#     await websocket.accept()
    
#     try:
#         pod_name = get_pod_name(job_id)
#         if not pod_name:
#             await websocket.send_text("Error: No pod found for this session")
#             await websocket.close()
#             return

#         v1 = client.CoreV1Api()
#         resp = stream(
#             v1.connect_get_namespaced_pod_exec,
#             pod_name,
#             "lang-app",
#             command=["/bin/sh"],
#             stderr=True, stdin=True, stdout=True, tty=True,
#             _preload_content=False
#         )

#         async def read_pod_output():
#             while resp.is_open():
#                 resp.update(timeout=1)
#                 if resp.peek_stdout():
#                     await websocket.send_text(resp.read_stdout())
#                 if resp.peek_stderr():
#                     await websocket.send_text(resp.read_stderr())

#         async def send_pod_input():
#             while True:
#                 data = await websocket.receive_text()
#                 if data.lower() in {"exit", "quit"}:
#                     resp.write_stdin("exit\n")
#                     break
#                 resp.write_stdin(data + "\n")

#         await asyncio.gather(read_pod_output(), send_pod_input())
        
#     except WebSocketDisconnect:
#         print("Client disconnected")
#     except Exception as e:
#         await websocket.send_text(f"Error: {str(e)}")
#     finally:
#         if 'resp' in locals():
#             resp.close()

@app.websocket("/ws/{job_id}")
async def websocket_terminal(websocket: WebSocket, job_id: str):
    await websocket.accept()

    # Wait for pod to be ready (polling)
    pod_name = None
    for _ in range(30):  # Retry for ~15 seconds
        pod_name = get_pod_name(job_id)
        if pod_name:
            break
        await asyncio.sleep(0.5)

    if not pod_name:
        await websocket.send_text("Error: Pod not ready or doesn't exist yet.")
        await websocket.close(code=1011)
        return

    try:
        v1 = client.CoreV1Api()
        exec_command = ["/bin/sh"]
        resp = stream(
            v1.connect_get_namespaced_pod_exec,
            pod_name,
            "lang-app",
            command=exec_command,
            stderr=True,
            stdin=True,
            stdout=True,
            tty=True,
            _preload_content=False,
        )

        async def read_stdout():
            while resp.is_open():
                resp.update(timeout=1)
                if resp.peek_stdout():
                    await websocket.send_text(resp.read_stdout())
                if resp.peek_stderr():
                    await websocket.send_text(resp.read_stderr())

        async def write_stdin():
            while True:
                try:
                    msg = await websocket.receive_text()
                    if msg.strip().lower() in {"exit", "quit"}:
                        resp.write_stdin("exit\n")
                        break
                    resp.write_stdin(msg + "\n")
                except WebSocketDisconnect:
                    break
                except Exception as e:
                    await websocket.send_text(f"Error: {str(e)}")
                    break

        await asyncio.gather(read_stdout(), write_stdin())

    except Exception as e:
        await websocket.send_text(f"Error during WebSocket session: {str(e)}")
    finally:
        if 'resp' in locals():
            resp.close()
        await websocket.close()


def get_filename(language: str) -> str:
    """Get appropriate filename based on language"""
    extensions = {
        "python": "main.py",
        "javascript": "main.js",
        "go": "main.go",
        "java": "Main.java",
        "csharp": "Program.cs"
    }
    return extensions.get(language, "code.txt")

def generate_job_yaml(language: str, file_paths: list, job_id: str):
    # Define the basic template for the Job YAML
    job_template = """
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: user-code-job-{job_id}
    spec:
      ttlSecondsAfterFinished: 60
      template:
        spec:
          containers:
          - name: user-code
            image: {image}
            command: {command}
            volumeMounts:
            - name: code-volume
              mountPath: /app/code
          restartPolicy: Never
          volumes:
          - name: code-volume
            configMap:
              name: user-code-configmap-{job_id}
    """

    # Determine the container image and command based on language
    if language == "python":
        image = "python:3.12-slim"
        command = ["python", "/app/code/main.py"]

    elif language == "node":
        image = "node:16"
        # Allow importing other JS files relative to /app/code
        command = ["/bin/sh", "-c", "node /app/code/main.js"]

    elif language == "go":
        image = "golang:1.19"
        # Go must be run from the directory to access all files in the package
        go_files = " ".join([f"/app/code/{os.path.basename(file)}" for file in file_paths])
        command = ["/bin/sh", "-c", f"cd /app/code && go run {go_files} && sleep 60"]
    else:
        raise ValueError(f"Unsupported language: {language}")

    # Return the complete job YAML with unique placeholders replaced
    job_yaml = job_template.format(
        job_id=job_id, image=image, command=command
    )
    return job_yaml

# def create_k8s_job(job_yaml: str):
#     # Write the YAML to a temporary file and apply it using kubectl or Kubernetes API
#     job_file = "/tmp/job.yaml"
#     with open(job_file, "w") as f:
#         f.write(job_yaml)

#     subprocess.run(["kubectl", "apply", "-f", job_file], check=True)

def create_k8s_job(job_yaml: str, job_id: str, namespace: str = "lang-app"):
    # Write the YAML to a temporary file
    job_file = "/tmp/job.yaml"
    with open(job_file, "w") as f:
        f.write(job_yaml)

    # Apply the Job YAML
    subprocess.run(["kubectl", "apply", "-f", job_file, "-n", namespace], check=True)

    # Print job info
    job_name = f"user-code-job-{job_id}"
    configmap_name = f"user-code-configmap-{job_id}"

    print(f"Job created: {job_name}")
    print(f"ConfigMap used: {configmap_name}")

    # Optionally, get the Pod name created by the Job
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
        else:
            print("⚠️ Pod not yet created or not found.")
    except subprocess.CalledProcessError as e:
        print(f"⚠️ Failed to retrieve pod: {e.stderr}")


# def generate_workflow_yaml(language: str, file_paths: list, job_id: str) -> str:
#     if language == "python":
#         image = "python:3.12-slim"
#         command = ["python", "/app/code/main.py"]

#     elif language == "node":
#         image = "node:16"
#         command = ["/bin/sh", "-c", "node /app/code/main.js"]

#     elif language == "go":
#         image = "golang:1.19"
#         # go_files = " ".join([f"/app/code/{os.path.basename(file)}" for file in file_paths])
#         go_files = " ".join([os.path.basename(file) for file in file_paths])
#         # command = ["/bin/sh", "-c", f"cd /app/code && GO111MODULE=off go run {go_files} && sleep 60"]
#         command = ["/bin/sh", "-c", f"cd /app/code && GO111MODULE=off go run *.go && sleep 300"]

#     else:
#         raise ValueError(f"Unsupported language: {language}")

#     workflow = {
#         "apiVersion": "argoproj.io/v1alpha1",
#         "kind": "Workflow",
#         "metadata": {
#             "generateName": f"user-code-run-{job_id}-",
#             "namespace": "lang-app"
#         },
#         "spec": {
#             "ttlStrategy": {
#                 "secondsAfterCompletion": 3600
#             },
#             "entrypoint": "run-code",
#             "templates": [
#                 {
#                     "name": "run-code",
#                     "container": {
#                         "image": image,
#                         "command": command,
#                         "volumeMounts": [
#                             {
#                                 "name": "code-volume",
#                                 "mountPath": "/app/code"
#                             }
#                         ]
#                     },
#                     "volumes": [
#                         {
#                             "name": "code-volume",
#                             "configMap": {
#                                 "name": f"user-code-configmap-{job_id}"
#                             }
#                         }
#                     ]
#                 }
#             ]
#         }
#     }

#     return yaml.dump(workflow, default_flow_style=False)

# def create_k8s_workflow(workflow_yaml: str):
#     # Write the workflow YAML to a temporary file and apply it using kubectl or Kubernetes API
#     workflow_file = "/tmp/workflow.yaml"
#     with open(workflow_file, "w") as f:
#         f.write(workflow_yaml)
    
#     # # Example: apply using kubectl command (you can change this to use Kubernetes API client)
#     # import subprocess
#     subprocess.run(["kubectl", "create", "-f", workflow_file], check=True)


# def create_k8s_workflow(workflow_yaml: str, namespace: str = "lang-app"):
#     workflow_file = "/tmp/workflow.yaml"
#     with open(workflow_file, "w") as f:
#         f.write(workflow_yaml)
    
#     # Apply the workflow YAML
#     subprocess.run(["kubectl", "create", "-f", workflow_file, "-n", namespace], check=True)

#     # Parse the workflow YAML to get the generated name prefix
#     doc = yaml.safe_load(workflow_yaml)
#     generate_name_prefix = doc.get("metadata", {}).get("generateName")
    
#     if not generate_name_prefix:
#         print("No generateName found in workflow metadata.")
#         return

#     # The actual workflow name will start with generate_name_prefix + some random suffix
#     # We wait a bit for the workflow to be created, then list workflows starting with that prefix
#     time.sleep(2)

#     # Get workflow name using kubectl
#     result = subprocess.run(
#         ["kubectl", "get", "wf", "-n", namespace, "-o", "jsonpath={.items[?(@.metadata.generateName=='"+generate_name_prefix+"')].metadata.name}"],
#         capture_output=True,
#         text=True
#     )

#     workflow_name = result.stdout.strip()
#     if not workflow_name:
#         # If above jsonpath doesn't work (because generateName is not preserved),
#         # list all workflows and pick the latest matching prefix
#         result = subprocess.run(
#             ["kubectl", "get", "wf", "-n", namespace, "-o", "jsonpath={.items[*].metadata.name}"],
#             capture_output=True,
#             text=True
#         )
#         all_names = result.stdout.split()
#         matched_names = [name for name in all_names if name.startswith(generate_name_prefix)]
#         if not matched_names:
#             print("Workflow not found after creation.")
#             return
#         workflow_name = sorted(matched_names)[-1]

#     print(f"Workflow created: {workflow_name}")

#     # Get the status of the workflow
#     status_result = subprocess.run(
#         ["kubectl", "get", "wf", workflow_name, "-n", namespace, "-o", "jsonpath={.status.phase}"],
#         capture_output=True,
#         text=True
#     )
#     status = status_result.stdout.strip()
#     print(f"Workflow status: {status}")


def create_configmap(job_id: str, file_paths: list):
    # Create a ConfigMap to store the code files
    configmap_name = f"user-code-configmap-{job_id}"
    config_map_data = {}

    # Add files to ConfigMap data
    for file_path in file_paths:
        with open(file_path, "r") as f:
            config_map_data[os.path.basename(file_path)] = f.read()

    config_map_body = {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {"name": configmap_name},
        "data": config_map_data
    }

    # Apply ConfigMap using kubectl or Kubernetes API
    configmap_yaml = yaml.dump(config_map_body, default_flow_style=False)
    configmap_file = "/tmp/configmap.yaml"
    with open(configmap_file, "w") as f:
        f.write(configmap_yaml)

    subprocess.run(["kubectl", "apply", "-f", configmap_file], check=True)


@app.get("/logs/{job_id}")
def get_job_logs(job_id: str):
    pod_name = get_pod_name(job_id)
    if pod_name is None:
        return {"error": "Pod not found for job id."}

    # Stream logs using kubectl
    logs = subprocess.check_output(["kubectl", "logs", "-f", pod_name], stderr=subprocess.STDOUT)

    return {"logs": logs.decode("utf-8")}


def get_pod_name(job_id: str):
    v1 = client.CoreV1Api()
    pods = v1.list_namespaced_pod(namespace="lang-app", label_selector=f"job-name=user-code-job-{job_id}")
    if pods.items:
        return pods.items[0].metadata.name  # Get the first pod that matches the job name
    return None
