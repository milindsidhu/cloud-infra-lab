# Installation guide
This is a detailed guide to set-up and implement secure public DNS using Cloudflare Tunnel.

#### Step: 1
```bash
: 'Create an API toke with scope 
Type	Item	            Permission
Account	Cloudflare Tunnel	Edit
Zone	DNS	                Edit'

# create a namespace
kubectl create ns cloudflared

# create a cloudflare api key secret
kubectl create secret generic cloudflare-api-key \
  --from-literal=apiKey=<your-api-key> \
  --from-literal=email=<your-email> \
  --namespace=cloudflared

# create a tunnel-cred using the tunnel.json which is created by
# This opens a browser window to authenticate and select the domain.
# Once done, credentials are saved to ~/.cloudflared/cert.pem.
cloudflared tunnel login

# use the cert.pem to create a secret as below
kubectl create configmap tunnelcert --from-file=cert.pem=cert.pem -n cloudflared

# create your desired tunnel, this will provide a file as output (*.json)
cloudflared tunnel create <tunnel-name>

# now create a configMap with the json obtained
# two options

# a) create a secret (for helm standalone)
kubectl create secret generic tunnel-credentials --from-file=credentials.json=<path/to/tunnel-json-file-name>.json -n cloudflared

# b) create a congigMap (for argocd)
kubectl create configmap credentials --from-file=credentials.json=<path/to/tunnel-json-file-name>.json -n cloudflared


: 'Change Cloudflare TLS mode
Navigate to the “SSL/TLS” -> “Overview” dashboard in your domain, and change the mode from the default to “Full”.'
```
#### Step: 2

Option: 1
Use a Helm chart to deploy Cloudflared (standalone).

```bash
cat > tunnel-values.yaml <<EOF
cloudflare:
  tunnelName: "tunnel-name"
  tunnelId: "tunnel-id"
  secretName: "tunnel-credentials"
  ingress:
    - hostname: "*<domain>"
      service: "http://<your-nginx-ingress-name>.ingress-nginx.svc.cluster.local:80"
      originRequest:
        originServerName: dexworks.in
        noTLSVerify: true
    - service: http_status:404

resources:
  limits:
    cpu: "100m"
    memory: "128Mi"
  requests:
    cpu: "100m"
    memory: "128Mi"

replicaCount: 1
EOF

helm repo add cloudflare https://cloudflare.github.io/helm-charts
helm repo update
helm upgrade --install cloudflare cloudflare/cloudflare-tunnel \
  --namespace cloudflared \
  --values tunne-values.yaml \
  --wait
```  

Option: 2
Use an ArgoCD application (preferred).

```bash
kubectl create secret generic tunnel-credentials \
  --from-file=credentials.json="D:\WORKSPACE\LOCAL\tunnel.json" \
  --namespace=cloudflared

project: default
source:
  repoURL: https://helmcharts.gruntwork.io
  targetRevision: v0.2.12
  helm:
    values: |
      applicationName: cloudflared-argocd-admin
      replicaCount: 1
      containerResources:
        limits:
          cpu: "100m"
          memory: "128Mi"
        requests:
          cpu: "100m"
          memory: "128Mi"
      service:
        enabled: false
      ingress:
        enabled: false
      containerImage:
        repository: cloudflare/cloudflared
        tag: 2025.5.0
        pullPolicy: Always
      containerCommand:
        - "cloudflared"
        - "--no-autoupdate"
        - "tunnel"
        - "--config"
        - "/etc/cloudflared/config/config.yaml"
        - "--loglevel"
        - "info"
        - "run"
      configMaps:
        tunnelcert:
          as: volume
          subPath: cert.pem
          mountPath: /etc/cloudflared/cert.pem
        credentials:
          as: volume
          subPath: credentials.json
          mountPath: /etc/cloudflared/creds/credentials.json
        cloudflared:
          as: volume
          mountPath: /etc/cloudflared/config
          items:
            config.yaml:
              filePath: config.yaml
      customResources:
        enabled: true
        resources:
          cloudflared_configmap: |
            apiVersion: v1
            kind: ConfigMap
            metadata:
              name: cloudflared
              namespace: cloudflared
            data:
              config.yaml: |
                # Name of the tunnel you want to run
                tunnel: edf03371-7be3-4673-aeae-4baf7c76fd57
                credentials-file: /etc/cloudflared/creds/credentials.json
                # originRequest: # Top-level configuration
                #   connectTimeout: 30s
                # warp-routing:
                #   enabled: true
                metrics: 0.0.0.0:2000
                no-autoupdate: true
                ingress:
                # The "*<domain>", creates a wildcard CNAME, which futher creates CNAMES
                # automatically when prompted by external-dns
                - hostname: "*<domain>"
                  service: "http://nginx-ingress-controller.nginx-ingress-controller.svc.cluster.local:80"
                  # service: "http://argocd-server.argocd.svc.cluster.local.80"
                  # service: http://192.168.31.130:80
                  # service: http://10.103.193.249:80
                  originRequest:
                    originServerName: dexworks.in
                    noTLSVerify: true
                - service: http_status:404
  chart: k8s-service
destination:
  server: https://kubernetes.default.svc
  namespace: cloudflared
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
```

#### Step: 3

Install External-DNS.

```bash
helm repo add kubernetes-sigs https://kubernetes-sigs.github.io/external-dns/
helm repo update
helm upgrade --install external-dns kubernetes-sigs/external-dns \
  --namespace cloudflared \
  --set sources[0]=ingress \
  --set policy=sync \
  --set provider.name=cloudflare \
  --set env[0].name=CF_API_TOKEN \
  --set env[0].valueFrom.secretKeyRef.name=cloudflare-api-key \
  --set env[0].valueFrom.secretKeyRef.key=apiKey \
  --wait
```

#### Step: 4
Annotate the Ingress

```bash
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    # some/other/annotationKey: value
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
    external-dns.alpha.kubernetes.io/hostname: <subdomain><domain>
    external-dns.alpha.kubernetes.io/target: <tunnel-id>.cfargotunnel.com
spec:
  ingressClassName: nginx # use this to route to internal host, else will return 502 Bad Gateway
