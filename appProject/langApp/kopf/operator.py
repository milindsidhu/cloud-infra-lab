import kopf
import os
import kubernetes
from kubernetes.client import V1Secret, V1ObjectMeta
import logging

log_file_path = "/var/log/secretreplicator/operator.log"

# Create the directory if it doesn't exist
os.makedirs(os.path.dirname(log_file_path), exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(log_file_path),
        logging.StreamHandler()  # still logs to stdout too
    ]
)

kubernetes.config.load_incluster_config()

@kopf.on.create('kopf.dev', 'v1', 'secretreplicators')
@kopf.on.update('kopf.dev', 'v1', 'secretreplicators')
def replicate_secret(spec, namespace, name, **kwargs):
    _replicate(spec, namespace, name)

@kopf.timer('kopf.dev', 'v1', 'secretreplicators', interval=300)
def periodic_check(spec, namespace, name, **kwargs):
    _replicate(spec, namespace, name)

@kopf.on.delete('kopf.dev', 'v1', 'secretreplicators')
def on_delete(spec, name, namespace, **kwargs):
    api = kubernetes.client.CustomObjectsApi()
    try:
        cr = api.get_namespaced_custom_object(
            group="kopf.dev",
            version="v1",
            namespace=namespace,
            plural="secretreplicators",
            name=name
        )
        finalizers = cr.get("metadata", {}).get("finalizers", [])
        if "kopf.zalando.org/KopfFinalizerMarker" in finalizers:
            finalizers.remove("kopf.zalando.org/KopfFinalizerMarker")
            patch = {"metadata": {"finalizers": finalizers}}
            api.patch_namespaced_custom_object(
                group="kopf.dev",
                version="v1",
                namespace=namespace,
                plural="secretreplicators",
                name=name,
                body=patch
            )
            kopf.info(
                {'apiVersion': 'kopf.dev/v1', 'kind': 'SecretReplicator', 'metadata': {'name': name, 'namespace': namespace}},
                reason="FinalizerRemoved",
                message=f"Removed Kopf finalizer from {name}"
            )
    except Exception as e:
        kopf.logger.error(f"Failed to remove finalizer from {name}: {e}")
        raise kopf.TemporaryError(f"Error removing finalizer: {e}", delay=10)

def _replicate(spec, namespace, name):
    source_ns = spec['sourceNamespace']
    source_name = spec['sourceSecretName']
    target_name = spec['targetSecretName']

    api = kubernetes.client.CoreV1Api()

    # Log initial debug info
    kopf.info(
        {'apiVersion': 'kopf.dev/v1', 'kind': 'SecretReplicator', 'metadata': {'name': name, 'namespace': namespace}},
        reason="Debug",
        message=f"Replicating secret from {source_ns}/{source_name} to {namespace}/{target_name}"
    )

    try:
        source_secret = api.read_namespaced_secret(source_name, source_ns)
        kopf.info(
            {'apiVersion': 'v1', 'kind': 'Secret', 'metadata': {'name': source_name, 'namespace': source_ns}},
            reason="Debug",
            message=f"Source secret keys: {list(source_secret.data.keys()) if source_secret.data else 'No data'}"
        )
    except kubernetes.client.exceptions.ApiException as e:
        raise kopf.TemporaryError(f"Source secret not found: {e}", delay=30)

    metadata = V1ObjectMeta(
        name=target_name,
        namespace=namespace,
        labels=source_secret.metadata.labels or {},
        annotations=source_secret.metadata.annotations or {},
    )

    new_secret = V1Secret(
        metadata=metadata,
        data=source_secret.data,
        type=source_secret.type,
    )

    try:
        api.create_namespaced_secret(namespace, new_secret)
        kopf.info(
            {'apiVersion': 'v1', 'kind': 'Secret', 'metadata': {'name': target_name, 'namespace': namespace}},
            reason="Created",
            message=f"Secret {target_name} created."
        )
    except kubernetes.client.exceptions.ApiException as e:
        if e.status == 409:
            existing_secret = api.read_namespaced_secret(target_name, namespace)
            if existing_secret.data != source_secret.data:
                api.replace_namespaced_secret(target_name, namespace, new_secret)
                kopf.info(
                    {'apiVersion': 'v1', 'kind': 'Secret', 'metadata': {'name': target_name, 'namespace': namespace}},
                    reason="Updated",
                    message=f"Secret {target_name} updated."
                )
            else:
                kopf.info(
                    {'apiVersion': 'v1', 'kind': 'Secret', 'metadata': {'name': target_name, 'namespace': namespace}},
                    reason="Unchanged",
                    message=f"Secret {target_name} is already up-to-date."
                )
        else:
            kopf.info(
                {'apiVersion': 'v1', 'kind': 'Secret', 'metadata': {'name': target_name, 'namespace': namespace}},
                reason="Failed",
                message=f"Failed to create/update secret: {e}"
            )
            raise
