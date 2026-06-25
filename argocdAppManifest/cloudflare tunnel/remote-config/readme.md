## Initalization

```bash
# first create ingress in cloudflare tunnel for kubernetes on argo, 
# or create a tunnel on cloudflare tunnel website
- hostname: "kube<domain>"
    # service: https://kubernetes.default.svc:443
    service: https://x.x.x.x:6443
    originRequest:
    originServerName: dexworks.in
    noTLSVerify: true
```

## Create these resources

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: remote-user
  namespace: kube-system
---
apiVersion: v1
kind: Secret
metadata:
  name: remote-user-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: remote-user
type: kubernetes.io/service-account-token
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: remote-user-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: remote-user
    namespace: kube-system
EOF
```

## Step 1: Get your CA and Token

```bash
SECRET=remote-user-token
TOKEN=$(kubectl -n kube-system get secret $SECRET -o jsonpath='{.data.token}' | base64 -d)
CA=$(kubectl -n kube-system get secret $SECRET -o jsonpath='{.data.ca\.crt}')

# to verify 
echo "$TOKEN" | head -c 30 && echo
echo "$CA" | base64 -d | openssl x509 -noout -issuer
```

##  Step 2: Create remote-kubeconfig.yaml

```bash
apiVersion: v1
kind: Config
clusters:
- name: remote
  cluster:
    server: https://kube<domain>
    certificate-authority-data: <paste $CA here>
users:
- name: remote-user
  user:
    token: <paste $TOKEN here>
contexts:
- name: remote-context
  context:
    cluster: remote
    user: remote-user
current-context: remote-context


# to test
curl -k -H "Authorization: Bearer $TOKEN" https://kube<domain>/api

KUBECONFIG=remote-kubeconfig.yaml kubectl get nodes
```
