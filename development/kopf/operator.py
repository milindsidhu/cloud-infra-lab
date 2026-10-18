import kopf
import os
import kubernetes
from kubernetes.client import V1Secret, V1ObjectMeta
import logging

log_file_path = "/var/log/secretreplicator/operator.log"
os.makedirs(os.path.dirname(log_file_path), exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(log_file_path),
        logging.StreamHandler(),
    ],
)

try:
    kubernetes.config.load_incluster_config()
except kubernetes.config.config_exception.ConfigException:
    logging.info("Not running in-cluster; falling back to local kube config")
    kubernetes.config.load_kube_config()


@kopf.on.create("kopf.dev", "v1", "secretreplicators")
@kopf.on.update("kopf.dev", "v1", "secretreplicators")
def replicate_secret(spec, namespace, name, **kwargs):
    _replicate(spec, namespace, name)


@kopf.timer("kopf.dev", "v1", "secretreplicators", interval=300)
def periodic_check(spec, namespace, name, **kwargs):
    _replicate(spec, namespace, name)


def _get_spec_field(spec, field):
    value = spec.get(field)
    if not value:
        raise kopf.PermanentError(f"Required field '{field}' is missing or empty in SecretReplicator")
    return value


def _replicate(spec, namespace, name):
    source_ns = _get_spec_field(spec, "sourceNamespace")
    source_name = _get_spec_field(spec, "sourceSecretName")
    target_name = _get_spec_field(spec, "targetSecretName")

    api = kubernetes.client.CoreV1Api()

    kopf.info(
        {"apiVersion": "kopf.dev/v1", "kind": "SecretReplicator", "metadata": {"name": name, "namespace": namespace}},
        reason="Reconcile",
        message=f"Replicating secret from {source_ns}/{source_name} to {namespace}/{target_name}",
    )

    try:
        source_secret = api.read_namespaced_secret(source_name, source_ns)
    except kubernetes.client.exceptions.ApiException as e:
        if e.status == 404:
            raise kopf.TemporaryError(f"Source secret {source_ns}/{source_name} not found", delay=30)
        raise

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
            {"apiVersion": "v1", "kind": "Secret", "metadata": {"name": target_name, "namespace": namespace}},
            reason="Created",
            message=f"Secret {target_name} created.",
        )
    except kubernetes.client.exceptions.ApiException as e:
        if e.status == 409:
            existing_secret = api.read_namespaced_secret(target_name, namespace)
            if existing_secret.data != source_secret.data:
                api.replace_namespaced_secret(target_name, namespace, new_secret)
                kopf.info(
                    {"apiVersion": "v1", "kind": "Secret", "metadata": {"name": target_name, "namespace": namespace}},
                    reason="Updated",
                    message=f"Secret {target_name} updated.",
                )
            else:
                kopf.info(
                    {"apiVersion": "v1", "kind": "Secret", "metadata": {"name": target_name, "namespace": namespace}},
                    reason="Unchanged",
                    message=f"Secret {target_name} is already up-to-date.",
                )
        else:
            kopf.error(
                {"apiVersion": "v1", "kind": "Secret", "metadata": {"name": target_name, "namespace": namespace}},
                reason="Failed",
                message=f"Failed to create/update secret: {e}",
            )
            raise
