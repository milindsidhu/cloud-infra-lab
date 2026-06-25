The **K8s API server is on `10.0.2.15:6443`** (default kubeadm port).

---

## Your Exact Config

### Step 1: Create the tunnel (run on your host machine or master VM)

```bash
cloudflared tunnel login
cloudflared tunnel create k8s-api-tunnel
# Note the tunnel ID it outputs
```

---

### Step 2: Store credentials in the cluster

```bash
# SSH into master
ssh dex@192.168.1.18

kubectl create namespace cloudflared

kubectl create secret generic tunnel-credentials \
  --from-file=credentials.json=$HOME/.cloudflared/<TUNNEL_ID>.json \
  -n cloudflared
```

---

### Step 3: DNS route

```bash
cloudflared tunnel route dns k8s-api-tunnel k8s-api.yourdomain.com
```

---

### Step 4: Deploy cloudflared — use these exact values

**`cloudflared-config.yaml`**
```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudflared-config
  namespace: cloudflared
data:
  config.yaml: |
    tunnel: <TUNNEL_ID>
    credentials-file: /etc/cloudflared/credentials.json
    ingress:
      - hostname: k8s-api.solidshop.in
        service: https://10.0.2.15:6443
        originRequest:
          noTLSVerify: true
      - service: http_status:404
EOF
```

**`cloudflared-deployment.yaml`**
```yaml
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: cloudflared
  labels:
    app: cloudflared
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared:2025.4.0
          args:
            - tunnel
            - --config
            - /etc/cloudflared/config/config.yaml
            - --metrics
            - 0.0.0.0:2000
            - run
          volumeMounts:
            - name: config
              mountPath: /etc/cloudflared/config
              readOnly: true
            - name: creds
              mountPath: /etc/cloudflared
              readOnly: true
          livenessProbe:
            httpGet:
              path: /ready
              port: 2000
            initialDelaySeconds: 30
            periodSeconds: 10
            failureThreshold: 5
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "200m"
      volumes:
        - name: config
          configMap:
            name: cloudflared-config
        - name: creds
          secret:
            secretName: tunnel-credentials
EOF
```

```bash
kubectl apply -f cloudflared-config.yaml
kubectl apply -f cloudflared-deployment.yaml
```

---

### Step 5: Get your kubeconfig for the runner

On the master:
```bash
# Get cluster CA
cat /etc/kubernetes/pki/ca.crt | base64 -w 0

# Create service account + token
kubectl create serviceaccount github-runner -n default
kubectl create clusterrolebinding github-runner \
  --clusterrole=cluster-admin \
  --serviceaccount=default:github-runner
kubectl create token github-runner --duration=8760h
```

Then build your kubeconfig (save as a GitHub secret `KUBECONFIG`):
```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://k8s-api.solidshop.in   # your tunnel hostname
    # certificate-authority-data: <BASE64_CA_CERT>
    insecure-skip-tls-verify: true
  name: homelab
contexts:
- context:
    cluster: homelab
    user: github-runner
  name: homelab
current-context: homelab
users:
- name: github-runner
  user:
    token: <TOKEN_FROM_ABOVE>
```

---

### Step 6: GitHub Actions workflow

```yaml
jobs:
  deploy:
    runs-on: self-hosted  # your runner pod in the cluster
    steps:
      - uses: actions/checkout@v4

      - name: Configure kubectl
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG }}" > ~/.kube/config

      - name: Test
        run: kubectl get no -o wide
```
