# External Secrets Operator + AWS Secrets Manager

Sync secrets from AWS Secrets Manager into Kubernetes using External Secrets Operator (ESO), ClusterSecretStore, and ExternalSecret.

---

## Architecture

```
AWS Secrets Manager
        |
External Secrets Operator
        |
Kubernetes Secret
        |
Application (env / volume)
```

---

## 1. Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io

helm install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set installCRDs=true
```

---

## 2. Verify CRDs

```bash
kubectl get crds | grep external-secrets
kubectl api-resources | grep secretstore
```

Key CRDs installed:
- clustersecretstores.external-secrets.io
- secretstores.external-secrets.io
- externalsecrets.external-secrets.io

**API version note:** Use `external-secrets.io/v1` for ESO >= 0.9, and `external-secrets.io/v1beta1` for older versions. Always verify with `kubectl api-resources | grep secretstore` before applying manifests.

---

## 3. Create AWS Credentials Secret

Since IRSA is not available locally (Minikube), use static credentials:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: aws-creds
  namespace: external-secrets
type: Opaque
stringData:
  access-key: <AWS_ACCESS_KEY_ID>
  secret-access-key: <AWS_SECRET_ACCESS_KEY>
```

---

## 4. Create ClusterSecretStore

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-south-1
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: aws-creds
            key: access-key
            namespace: external-secrets
          secretAccessKeySecretRef:
            name: aws-creds
            key: secret-access-key
            namespace: external-secrets
```

Verify the store is ready:

```bash
kubectl describe clustersecretstore aws-secrets-manager
# Expected: Status: Ready = True
```

---

## 5. Create ExternalSecret

### Plain string secret

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: ghub-token
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: ghub-token
    creationPolicy: Owner
  data:
    - secretKey: token
      remoteRef:
        key: ghub-token
```

**creationPolicy: Owner** means if the ExternalSecret is deleted, the synced Kubernetes secret is also deleted. Use `creationPolicy: Orphan` if you want the secret to persist after the ExternalSecret is removed.

### JSON secret

If the AWS secret value is a JSON object like `{"token": "abcd123"}`, add the `property` field:

```yaml
data:
  - secretKey: token
    remoteRef:
      key: ghub-token
      property: token
```

---

## 6. Verify

```bash
kubectl get externalsecret
kubectl describe externalsecret ghub-token
kubectl get secret ghub-token -o yaml

# Decode the value
kubectl get secret ghub-token -o jsonpath="{.data.token}" | base64 -d
```

---

## 7. Use the Secret in a Deployment

### As an environment variable

```yaml
containers:
  - name: app
    image: nginx
    env:
      - name: GHUB_TOKEN
        valueFrom:
          secretKeyRef:
            name: ghub-token
            key: token
```

### As a mounted volume

```yaml
volumes:
  - name: secret-vol
    secret:
      secretName: ghub-token
containers:
  - name: app
    volumeMounts:
      - name: secret-vol
        mountPath: "/etc/secrets"
        readOnly: true
```

---

## 8. Security Improvements

### Least Privilege IAM Policy

```json
{
  "Effect": "Allow",
  "Action": [
    "secretsmanager:GetSecretValue",
    "secretsmanager:DescribeSecret"
  ],
  "Resource": "arn:aws:secretsmanager:ap-south-1:<ACCOUNT_ID>:secret:ghub-token-*"
}
```

### Temporary Credentials via STS

Instead of long-lived static keys:

```bash
aws sts get-session-token
```

Store all three values and reference the session token in ClusterSecretStore:

```yaml
auth:
  secretRef:
    sessionTokenSecretRef:
      name: aws-creds
      key: session-token
      namespace: external-secrets
```

---

## 9. IRSA (Production - EKS Only)

IRSA eliminates the need to store AWS credentials in the cluster. ESO assumes an IAM role via a Kubernetes ServiceAccount token.

### ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-sa
  namespace: external-secrets
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/external-secrets-role
```

### ClusterSecretStore with IRSA

```yaml
auth:
  jwt:
    serviceAccountRef:
      name: external-secrets-sa
      namespace: external-secrets
```

### IAM Trust Policy

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/<OIDC_PROVIDER>"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "<OIDC_PROVIDER>:sub": "system:serviceaccount:external-secrets:external-secrets-sa"
    }
  }
}
```

### IRSA Flow

```
Pod -> ServiceAccount -> JWT Token
    -> AWS STS (AssumeRoleWithWebIdentity)
    -> IAM Role -> Temporary Credentials
    -> Secrets Manager
```

---

## Dev vs Prod Comparison

| | Minikube (Dev) | EKS (Prod) |
|---|---|---|
| Auth method | Static or STS credentials | IRSA |
| OIDC provider | Not available | Built-in |
| Credentials stored in cluster | Yes | No |
| Security | Moderate | High |

**Minikube workaround:** Use [LocalStack](https://localstack.cloud) to simulate AWS Secrets Manager locally, avoiding real AWS credentials in development.

---

## Summary

- ESO syncs AWS secrets into Kubernetes on a configurable refresh interval
- Match the API version to your ESO install: `v1` for >= 0.9, `v1beta1` for older
- Plain and JSON secrets are handled differently - use `property` to extract a key from JSON
- `creationPolicy: Owner` ties the Kubernetes secret lifecycle to the ExternalSecret
- Static credentials work everywhere but IRSA is the production standard on EKS
- IRSA requires EKS with OIDC - use LocalStack or static creds for local dev

---

## Next Steps

- Integrate ExternalSecrets with ArgoCD ApplicationSets for GitOps-managed secrets
- Add secret rotation with a short `refreshInterval`
- Migrate to IRSA when deploying to EKS
- Use SOPS or SealedSecrets for securing secret references in Git