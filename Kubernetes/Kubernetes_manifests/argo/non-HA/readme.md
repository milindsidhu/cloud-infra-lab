# Installation guide
### Argo CD Setup

```bash
kubectl create ns argocd
kubectl apply -n argocd -f install.yaml
kubectl apply -n argocd -f config.yaml
kubectl scale -n argocd deployment/argocd-server --replicas=0 && kubectl scale -n argocd deployment/argocd-server --replicas=1
# kubectl apply -n argocd -f certificate.yaml
kubectl apply -n argocd -f ingress.yaml
