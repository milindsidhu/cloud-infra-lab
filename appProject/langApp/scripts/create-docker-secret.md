# Create a Docker Registry Secret

Create a `kubernetes.io/dockerconfigjson` Secret for image pulls.
Replace the placeholders with your registry credentials and target namespace.

```bash
kubectl create secret docker-registry <SECRET_NAME> \
  --docker-server=<DOCKER_REGISTRY_SERVER> \
  --docker-username=<DOCKER_USERNAME> \
  --docker-password=<DOCKER_PASSWORD_OR_PAT> \
  --docker-email=<DOCKER_EMAIL> \
  --namespace=<NAMESPACE>
```
