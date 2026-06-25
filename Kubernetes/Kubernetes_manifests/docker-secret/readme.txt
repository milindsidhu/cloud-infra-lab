kubectl create secret docker-registry my-registry-secret \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<your-username> \
  --docker-password=<your-PAT> \
  --docker-email=<your-email> \
  --namespace=<your-namespace> # probably default


then refer to it using the replicator 

apiVersion: v1
kind: Secret
metadata:
  name: docker-secret
  namespace: <your-namespace>
  annotations:
    replicator.v1.mittwald.de/replicate-from: <namespace-where-orginal-secret-is>/<secret-name>
type: Opaque
