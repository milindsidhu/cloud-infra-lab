
from fastapi import FastAPI, File, UploadFile, Form
from kubernetes import client, config
import uuid
import os
import subprocess
import shutil
import yaml
import time

app = FastAPI()

# load the kubernetes configuration
env_name = os.getenv("ENVIRONMENT")
current_namespace = os.getenv("NAMESPACE")

# Generate a unique job ID and names for the job and configmap
job_id = str(uuid.uuid4())

# Determine job and configmap names based on environment
if env_name == "prod":
    job_name = f"user-code-job-{job_id}"
    configmap_name = f"user-code-configmap-{job_id}"
else:
    job_name = f"{env_name}-user-code-job-{job_id}"
    configmap_name = f"{env_name}-user-code-configmap-{job_id}"

# Load Kubernetes config from within the cluster
config.load_incluster_config()

# Temporary directory to save user files
TEMP_DIR = "/tmp/user_files"

@app.get("/")
async def root(debug: bool = False):
    # Prepare pod list info
    # namespaces = ["lang-app", "default"]
    namespaces = [current_namespace]  # You can add more namespaces if needed
    pod_list = {}

    v1 = client.CoreV1Api()

    for namespace in namespaces:
        try:
            pods = v1.list_namespaced_pod(namespace=namespace)
            if not pods.items:
                pod_list[namespace] = "No pods found"
            else:
                pod_list[namespace] = [pod.metadata.name for pod in pods.items]
        except Exception as e:
            pod_list[namespace] = f"Error fetching pods: {str(e)}"

    # Main API status
    message = "Runner API is live."
    
    # Construct response
    response = {"status": "ok", "message": message, "pods": pod_list}
    
    # Add debug details if the debug flag is True
    if debug:
        response["debug"] = "Pod list fetched"
    
    return response

@app.get("/favicon.ico")
async def favicon():
    return {"detail": "Not Found"}  # Returning a simple response to avoid the 404 error

@app.post("/run")
async def run_code(
    language: str = Form(...),  # Accept language from the form body
    files: list[UploadFile] = File(...)):
    # Generate a unique job ID for the user's session
    # job_id = str(uuid.uuid4())

    # Create temporary directory to store code files
    os.makedirs(TEMP_DIR, exist_ok=True)

    # Save files to TEMP_DIR
    file_paths = []
    for file in files:
        file_path = os.path.join(TEMP_DIR, file.filename)
        file_paths.append(file_path)
        with open(file_path, "wb") as f:
            shutil.copyfileobj(file.file, f)

    # Generate the dynamic Kubernetes job YAML
    job_yaml = generate_job_yaml(language, file_paths, job_id, env_name)
    # workflow_yaml = generate_workflow_yaml(language, file_path, job_id)
    
    # Create the ConfigMap for the user code files
    create_configmap(job_id, file_paths)

    # Create Kubernetes Job
    create_k8s_job(job_yaml, current_namespace)
    # create_k8s_workflow(workflow_yaml)

    return {"message": f"Job created with ID: {job_id}", "job_id": job_id}


def generate_job_yaml(language: str, file_paths: list, job_id: str, env_name: str):
    # Define the basic template for the Job YAML
    job_template = """
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: {job_name}
      namespace: {current_namespace}
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
              name: {configmap_name}
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
        image=image, command=command, current_namespace=current_namespace,
        job_name=job_name, configmap_name=configmap_name, env_name=env_name
    )
    return job_yaml

# def create_k8s_job(job_yaml: str):
#     # Write the YAML to a temporary file and apply it using kubectl or Kubernetes API
#     job_file = "/tmp/job.yaml"
#     with open(job_file, "w") as f:
#         f.write(job_yaml)

#     subprocess.run(["kubectl", "apply", "-f", job_file], check=True)

def create_k8s_job(job_yaml: str, current_namespace: str = "lang-app"):
    # Write the YAML to a temporary file
    job_file = "/tmp/job.yaml"
    with open(job_file, "w") as f:
        f.write(job_yaml)

    # Apply the Job YAML
    subprocess.run(["kubectl", "apply", "-f", job_file, "-n", current_namespace], check=True)

    # # Print job info
    # job_name = f"user-code-job-{job_id}"
    # configmap_name = f"user-code-configmap-{job_id}"

    print(f"Job created: {job_name}")
    print(f"ConfigMap used: {configmap_name}")

    # Optionally, get the Pod name created by the Job
    try:
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", current_namespace, "-l", f"job-name={job_name}", "-o", "jsonpath={.items[0].metadata.name}"],
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
    # configmap_name = f"user-code-configmap-{job_id}"
    config_map_data = {}

    # Add files to ConfigMap data
    for file_path in file_paths:
        with open(file_path, "r") as f:
            config_map_data[os.path.basename(file_path)] = f.read()

    config_map_body = {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {
            "name": configmap_name,
            "namespace": current_namespace
        },
        "data": config_map_data
    }

    # Apply ConfigMap using kubectl or Kubernetes API
    configmap_yaml = yaml.dump(config_map_body, default_flow_style=False)
    configmap_file = "/tmp/configmap.yaml"
    with open(configmap_file, "w") as f:
        f.write(configmap_yaml)

    subprocess.run(["kubectl", "apply", "-f", configmap_file, "-n", current_namespace], check=True)


# @app.get("/logs/{job_id}")
# def get_job_logs(job_id: str):
#     pod_name = get_pod_name(job_id)
#     if pod_name is None:
#         return {"error": "Pod not found for job id."}

#     # Stream logs using kubectl
#     logs = subprocess.check_output(["kubectl", "logs", "-f", pod_name], stderr=subprocess.STDOUT)

#     return {"logs": logs.decode("utf-8")}


# def get_pod_name(job_id: str):
#     v1 = client.CoreV1Api()
#     # pods = v1.list_namespaced_pod(namespace="lang-app", label_selector=f"job-name=user-code-job-{job_id}")
#     pods = v1.list_namespaced_pod(namespace=current_namespace, label_selector=f"job-name={job_name}")
#     if pods.items:
#         return pods.items[0].metadata.name  # Get the first pod that matches the job name
#     return None

@app.get("/logs/{job_id}")
def get_job_logs(job_id: str):
    pod_name = get_pod_name(job_id)
    if pod_name is None:
        return {"error": "Pod not found for job id."}

    try:
        # Fetch logs without following
        logs = subprocess.check_output(
            ["kubectl", "logs", pod_name, "-n", current_namespace],
            stderr=subprocess.STDOUT
        )
        return logs.decode("utf-8")
    except subprocess.CalledProcessError as e:
        return {"error": f"Failed to get logs: {e.output.decode('utf-8')}"}

def get_pod_name(job_id: str):
    v1 = client.CoreV1Api()
    
    # Construct correct job name based on env_name and job_id
    if env_name == "prod":
        job_name_local = f"user-code-job-{job_id}"
    else:
        job_name_local = f"user-code-job-{env_name}-{job_id}"

    try:
        pods = v1.list_namespaced_pod(
            namespace=current_namespace,
            label_selector=f"job-name={job_name_local}"
        )
        if pods.items:
            return pods.items[0].metadata.name
    except Exception as e:
        print(f"Error getting pod name: {str(e)}")
    
    return None
