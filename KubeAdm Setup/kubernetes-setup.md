# Kubernetes Cluster Setup Guide (Master + Worker)

> **Environment:** VirtualBox VMs using a **NAT Network** (not regular NAT).
> Each VM receives a unique IP on the same subnet (e.g., `10.0.2.15`, `10.0.2.16`),
> can communicate with other VMs directly, and has internet access — all on one interface.
>
> All steps marked **[BOTH]** run on master and every worker.
> Steps marked **[MASTER]** or **[WORKER]** are node-specific.

---

## Variables (set once, used throughout)

```bash
KUBERNETES_VERSION=v1.32
CRIO_VERSION=v1.32
POD_CIDR="10.1.0.0/16"
CLUSTER_IF="enp0s3"   # NAT Network interface — unique IP per VM, internet + cluster traffic
```

---

## Step 1 — Load Kernel Modules [BOTH]

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

---

## Step 2 — Sysctl Parameters [BOTH]

```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

---

## Step 3 — Disable Swap Permanently [BOTH]

The crontab approach has a race condition on reboot (swap comes back before kubelet starts).
Edit `/etc/fstab` instead so swap is never mounted.

```bash
sudo swapoff -a
sudo sed -i '/\bswap\b/d' /etc/fstab
```

Verify swap is gone:

```bash
free -h   # Swap line should show 0
```

---

## Step 4 — Open Required Firewall Ports [BOTH]

```bash
# Master node ports
sudo ufw allow 6443/tcp          # Kubernetes API server
sudo ufw allow 2379:2380/tcp     # etcd client and peer
sudo ufw allow 10250/tcp         # kubelet API
sudo ufw allow 10259/tcp         # kube-scheduler
sudo ufw allow 10257/tcp         # kube-controller-manager

# Worker node ports (run on workers too — harmless on master)
sudo ufw allow 30000:32767/tcp   # NodePort services

# Allow all pod CIDR traffic across nodes
sudo ufw allow from 10.1.0.0/16

sudo ufw reload
```

---

## Step 5 — Install Dependencies [BOTH]

```bash
sudo apt-get update
sudo apt-get install -y software-properties-common curl apt-transport-https \
                        ca-certificates gnupg lsb-release jq
```

### Add Kubernetes Repository

```bash
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key \
  | sudo gpg --dearmor \
  | sudo tee /etc/apt/keyrings/kubernetes-apt-keyring.gpg > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
```

### Add CRI-O Repository

```bash
curl -fsSL https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v1.32/deb/Release.key \
  | sudo gpg --dearmor \
  | sudo tee /etc/apt/keyrings/cri-o-apt-keyring.gpg > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] \
https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v1.32/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/cri-o.list > /dev/null
```

### Install Packages

```bash
sudo apt-get update
sudo apt-get install -y cri-o runc kubelet kubeadm kubectl

# Pin versions so apt upgrade doesn't break the cluster
sudo apt-mark hold kubelet kubeadm kubectl
```

### Start CRI-O

```bash
sudo systemctl enable --now crio

crio --version
runc --version
```

---

## Step 6 — Configure Node IP [BOTH]

> **NAT Network** assigns each VM a unique IP on the same subnet, so a single interface
> handles both cluster traffic and internet. No bridge adapter or route juggling needed.

```bash
# Verify the interface exists
ip link show "$CLUSTER_IF" > /dev/null 2>&1 \
  || { echo "ERROR: interface $CLUSTER_IF not found — check VirtualBox adapter name"; exit 1; }

# Read the unique IP assigned by VirtualBox NAT Network
local_ip="$(ip -4 addr show "$CLUSTER_IF" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
[[ -z "$local_ip" ]] && { echo "ERROR: no IPv4 on $CLUSTER_IF"; exit 1; }
echo "Node IP: $local_ip"

# Tell kubelet which IP to advertise
echo "KUBELET_EXTRA_ARGS=--node-ip=$local_ip" | sudo tee /etc/default/kubelet > /dev/null

# Confirm internet access (NAT Network routes this automatically)
curl -fsSL --max-time 5 https://github.com > /dev/null \
  && echo "Internet: OK" || echo "WARNING: no internet — check VirtualBox NAT Network settings"
```

---

## Step 7 — Initialize the Master Node [MASTER]

```bash
export IPADDR="$local_ip"   # NAT Network IP — unique per VM, reachable by all nodes
export NODENAME=$(hostname -s | tr '[:upper:]' '[:lower:]')

sudo kubeadm init \
  --cri-socket=unix:///var/run/crio/crio.sock \
  --apiserver-advertise-address="$IPADDR" \
  --apiserver-cert-extra-sans="$IPADDR" \
  --pod-network-cidr="$POD_CIDR" \
  --node-name "$NODENAME" \
  --ignore-preflight-errors Swap \
  --v=5
```

### Configure kubeconfig

```bash
mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
```

### Save the Join Command

```bash
sudo kubeadm token create --print-join-command | tee ~/join-command.sh
chmod 600 ~/join-command.sh
echo "--- Share ~/join-command.sh with each worker node ---"
```

> **Optional — single node cluster:** If running without dedicated workers, untaint the master so pods can schedule on it:
> ```bash
> kubectl taint nodes --all node-role.kubernetes.io/control-plane-
> ```

---

## Step 8 — Install CNI [MASTER]

> **Install CNI before joining workers or fixing CoreDNS.** CoreDNS pods will stay in
> `Pending` until a CNI is present — patching or restarting them before this point has no effect.

### Option A — Calico

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.0/manifests/calico.yaml

# Wait for all Calico pods to be Running before continuing
kubectl -n kube-system wait --for=condition=Ready pod -l k8s-app=calico-node --timeout=120s
```

### Option B — Cilium

```bash
CILIUM_CLI_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
[[ "$(uname -m)" == "aarch64" ]] && CLI_ARCH=arm64

curl -fsSL --remote-name-all \
  https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar -xzf cilium-linux-${CLI_ARCH}.tar.gz -C /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

cilium install --version 1.17.5
cilium status --wait
```

---

## Step 9 — Join Worker Nodes [WORKER]

Copy `~/join-command.sh` from the master to each worker, then run:

```bash
# On each worker node (run Steps 1–6 first)
sudo bash ~/join-command.sh --cri-socket=unix:///var/run/crio/crio.sock
```

Verify from the master:

```bash
kubectl get nodes -o wide
# All nodes should show Ready and their IPs in the IP column
```

---

## Step 10 — Fix CoreDNS for External DNS [MASTER]

> **Do this after CNI is installed and all nodes are Ready.** CoreDNS pods must be Running
> before the patch and rollout restart will take effect. Pods inherit DNS from CoreDNS —
> if CoreDNS can't resolve `github.com`, ArgoCD can't reach GitHub even if the node can.

```bash
kubectl -n kube-system patch configmap coredns --type merge -p "$(cat <<'EOF'
{
  "data": {
    "Corefile": ".:53 {\n    errors\n    health {\n       lameduck 5s\n    }\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n       pods insecure\n       fallthrough in-addr.arpa ip6.arpa\n       ttl 30\n    }\n    prometheus :9153\n    forward . 8.8.8.8 1.1.1.1\n    cache 30\n    loop\n    reload\n    loadbalance\n}\n"
  }
}
EOF
)"

kubectl -n kube-system rollout restart deployment coredns
kubectl -n kube-system rollout status deployment coredns
```

### Verify DNS Works from a Pod

```bash
kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never \
  -- nslookup github.com
# Expected: Server: 10.96.0.10 (CoreDNS ClusterIP), then GitHub IPs
```

---

## Step 11 — Verify Pod Masquerade (CNI Internet Access) [MASTER]

> Pods must SNAT through the NAT interface to reach the internet. Calico/Cilium handle
> this automatically, but verify before installing workloads.

```bash
# Check iptables masquerade rules exist for pod CIDR
sudo iptables -t nat -L POSTROUTING -n -v | grep -E "MASQ|10\.1\."

# Test outbound internet from a pod — this is what ArgoCD does
kubectl run internet-test --image=curlimages/curl --rm -it --restart=Never \
  -- curl -I https://github.com
# Expected: HTTP/2 200

# If the above fails but node curl works, add masquerade manually:
# sudo iptables -t nat -A POSTROUTING -s 10.1.0.0/16 ! -d 10.1.0.0/16 -o "$CLUSTER_IF" -j MASQUERADE
```

---

## Step 12 — Install Metrics Server [MASTER]

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

kubectl patch deployment metrics-server -n kube-system --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-preferred-address-types=InternalIP,Hostname,InternalDNS,ExternalDNS,ExternalIP"
  }
]'

kubectl -n kube-system rollout status deployment metrics-server

# Verify
kubectl top node
```

---

## Step 13 — Default Storage Class [MASTER]

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml

kubectl patch storageclass local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl get storageclass
# local-path should show (default)
```

---

## Step 14 — Check Node and System Status [MASTER]

```bash
kubectl get nodes -o wide
kubectl get po -n kube-system
kubectl top node
```

---

## Troubleshooting: ArgoCD Cannot Reach GitHub

Run these checks in order to isolate the failure:

```bash
# 1. DNS resolution from inside a pod
kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never \
  -- nslookup github.com

# 2. HTTPS from inside a pod
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never \
  -- curl -I https://github.com

# 3. Check the default route exits via the NAT Network interface
ip route show | grep default
# Must contain: dev enp0s3 (or whatever $CLUSTER_IF is)

# 4. Check masquerade rules for pod CIDR
sudo iptables -t nat -L POSTROUTING -n -v | grep MASQ

# 5. ArgoCD repo-server logs
kubectl -n argocd logs deployment/argocd-repo-server | grep -i "error\|dial\|timeout"

# 6. CoreDNS logs
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=50
```

### After fixing DNS or routing, restart ArgoCD

```bash
kubectl -n argocd rollout restart deployment argocd-repo-server
kubectl -n argocd rollout status deployment argocd-repo-server
```