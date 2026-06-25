# Kubernetes Setup Guide for Master and Worker Nodes

This document provides a step-by-step guide for setting up Kubernetes on both the master and worker nodes. Some steps are common for both nodes, while others are specific to the master node.

---

## Step 1: Load Kernel Modules on Both Nodes

On both the master and worker nodes, load the necessary kernel modules:

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
```

---

## Step 2: Apply Kernel Modules on Both Nodes

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

---

## Step 3: Set Sysctl Parameters on Both Nodes

```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
```

---

## Step 4: Apply Sysctl Settings on Both Nodes

```bash
sudo sysctl --system
```

---

## Step 5: Disable Swap on Both Nodes

```bash
sudo swapoff -a
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true
```

---

## Step 6: Define Kubernetes and CRI-O Versions

```bash
KUBERNETES_VERSION=v1.32
CRIO_VERSION=v1.32
```

---

## Step 7: Install Dependencies on Both Nodes

```bash
sudo apt-get update
sudo apt-get install -y software-properties-common curl
```

### Add the Kubernetes Repository:

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor | sudo tee /etc/apt/keyrings/kubernetes-apt-keyring.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
```

### Add CRI-O Repository:

```bash
curl -fsSL https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor | sudo tee /etc/apt/keyrings/cri-o-apt-keyring.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v1.32/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list > /dev/null
```

### Install Packages:

```bash
sudo apt-get update
sudo apt-get install -y cri-o runc kubelet kubeadm kubectl
```

### Start CRI-O:

```bash
sudo systemctl enable crio
sudo systemctl start crio
crio --version
runc --version
```

---

## Step 8: Install jq on Both Nodes

```bash
sudo apt-get install -y jq
```

---

## Step 9: Define Local IP Address on Both Nodes

```bash
ifconfig
local_ip="$(ip --json a s | jq -r '.[] | if .ifname == "enp0s3" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
echo "KUBELET_EXTRA_ARGS=--node-ip=$local_ip" | sudo tee /etc/default/kubelet > /dev/null
```

---

## Step 10: Initialize the Master Node

```bash
echo $local_ip
export IPADDR="$local_ip"
export NODENAME=$(hostname -s | tr '[:upper:]' '[:lower:]')
export POD_CIDR="10.1.0.0/16"
sudo kubeadm init --cri-socket=unix:///var/run/crio/crio.sock --apiserver-advertise-address=$IPADDR --apiserver-cert-extra-sans=$IPADDR --pod-network-cidr=$POD_CIDR --node-name $NODENAME --ignore-preflight-errors Swap --v=5
```

### Get the Join Command:

```bash
sudo kubeadm token create --print-join-command
```

### Configure kubeconfig:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## Step 11: Check Node Status on Master Node

```bash
kubectl get po -n kube-system
```

---

## Step 12: Join the Worker Node

```bash
sudo kubeadm join ......
```

---

## Step 13: Install Calico Network Plugin for Pod Networking

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.0/manifests/calico.yaml
```

### OR Install Cilium:

```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
cilium install --version 1.17.5
cilium status
```

---

## Step 14: Install Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system edit deployment metrics-server
```

Add the following arguments under `spec.containers.args`:

```yaml
- --kubelet-insecure-tls
- --kubelet-preferred-address-types=InternalIP,Hostname,InternalDNS,ExternalDNS,ExternalIP
```

---

## Step 15: Verify Metrics Server and Node Metrics

```bash
kubectl top node
```

---

## Step 16: Configure DNS

```bash
sudo nmcli con mod "Wired connection 1" ipv4.dns "8.8.8.8 1.1.1.1"
sudo nmcli con mod "Wired connection 1" ipv4.ignore-auto-dns yes
sudo nmcli con down "Wired connection 1" && sudo nmcli con up "Wired connection 1"

kubectl -n kube-system edit configmap coredns
```

Look for a line like:

```text
forward . /etc/resolv.conf
```

Replace it with:

```text
forward . 8.8.8.8 1.1.1.1
```

```bash
kubectl -n kube-system rollout restart deployment coredns
dig github.com
curl -I https://github.com
ping github.com
```

---

## Step 17: Create Default Storage / HostPath

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

