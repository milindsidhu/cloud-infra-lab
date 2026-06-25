### Steps to Install Nginx-Ingress-Controller

```bash
# create a ns
kubectl create namespace ingress-nginx

helm upgrade --install ingress-nginx oci://ghcr.io/nginx/charts/nginx-ingress --namespace ingress-nginx
```

To use ClusterIP instead of LoadBalancer, use this method, works with external-dns and cloudflare tunnel.

```bash
helm upgrade --install ingress-nginx oci://ghcr.io/nginx/charts/nginx-ingress --namespace ingress-nginx --version 2.1.0 \
    --set controller.service.type=ClusterIP \
    --set controller.ingressClassResource.default=true \
    --wait
```
