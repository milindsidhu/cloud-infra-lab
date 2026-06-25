# Install ArgoCD
``` bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

# Wait for ArgoCD to be ready
``` bash
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s
```

# Switch to insecure mode (HTTP internally)
``` bash
kubectl patch configmap argocd-cmd-params-cm -n argocd \
  --type merge \
  -p '{"data":{"server.insecure":"true"}}'
```

# Restart ArgoCD server
``` bash
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd
```