Alright—here’s a **clean, detailed, production-style note set with YAML + explanations**.
You can literally turn this into a README or interview prep doc.

---

# External Secrets + AWS Secrets Manager (Minikube → IRSA Concepts)

---

# Before You Begin

All application resources below use a dedicated namespace called `demo`.
Create it first (replace `demo` with your real namespace):

```bash
kubectl create namespace demo
```

---

# 1. Objective

Sync secrets from **AWS Secrets Manager** into Kubernetes using:

* External Secrets Operator (ESO)
* ClusterSecretStore
* ExternalSecret

---

# 2. Architecture Overview

### 2.1 Local (Minikube)

```
AWS Secrets Manager
        ↓
External Secrets Operator
        ↓
Kubernetes Secret
        ↓
Application (env / volume)
```

---

# 3. Install External Secrets Operator

Using Helm:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set installCRDs=true
```

> ⚠️ **CRD upgrade caveat:** `--set installCRDs=true` only installs CRDs on the
> first `helm install`. Helm 3 does **not** upgrade CRDs automatically on
> `helm upgrade`. For upgrades, also pass:
> ```bash
> --set crds.enabled=true --set crds.keep=true
> ```
> or apply the CRDs manually before upgrading.

---

# 4. Verify CRDs

```bash
kubectl get crds | grep external-secrets
```

Important CRDs:

* `clustersecretstores.external-secrets.io`
* `secretstores.external-secrets.io`
* `externalsecrets.external-secrets.io`

---

# 5. API Version Gotcha

Check supported version:

```bash
kubectl api-resources | grep secretstore
```

Output:

```
external-secrets.io/v1
```

👉 Use:

```yaml
apiVersion: external-secrets.io/v1
```

> ⚠️ `external-secrets.io/v1` is served from ESO chart **v0.17.0** onwards. If
> you are pinned to an older chart (`< v0.17.0`), use `external-secrets.io/v1beta1`
> instead. `kubectl api-resources | grep secretstore` will show the served
> version for your cluster.

---

# 6. AWS Secret Details

Example:

* Secret Name: `ghub-token`
* Type: Plain string

---

# 7. Create AWS Credentials Secret (Minikube)

Since [IRSA is not available locally](#15-why-irsa-does-not-work-on-minikube):

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: aws-creds
  namespace: external-secrets
type: Opaque
stringData:
  access-key: <AWS_ACCESS_KEY_ID>
  secret-access-key: <AWS_SECRET_ACCESS_KEY>
EOF
```

> ⚠️ **Never commit this Secret to Git.** These are long-lived IAM user keys.
> Use them only for local Minikube. In EKS, switch to [IRSA (Section 14)](#14-irsa-production-concept).

---

# 8. Create ClusterSecretStore

```bash
kubectl apply -f - <<EOF
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
EOF
```

---

## 8.1 Verify Store

```bash
kubectl describe clustersecretstore aws-secrets-manager
```

Expected:

```
Status: Ready = True
```

---

# 9. Create ExternalSecret

## 9.1 Case: Plain string secret

```bash
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: ghub-token
  namespace: demo   # replace with your real application namespace
spec:
  refreshInterval: 1h   # polling every hour; increase or use refreshPolicy: OnChange (v1) to reduce AWS API calls
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: ghub-token
    creationPolicy: Owner   # deleting this ExternalSecret also deletes the generated Secret
    # deletionPolicy: Delete   # default; use Retain if you need the Secret to outlive the ExternalSecret
  data:
    - secretKey: token
      remoteRef:
        key: ghub-token
EOF
```

---

## 9.2 Case: JSON secret

If AWS secret is:

```json
{
  "token": "abcd123"
}
```

Then:

```yaml
data:
  - secretKey: token
    remoteRef:
      key: ghub-token
      property: token
```

---

# 10. Resulting Kubernetes Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ghub-token
type: Opaque
data:
  token: <base64-encoded-value>
```

---

# 11. Verification

```bash
kubectl get externalsecret -n demo
kubectl describe externalsecret ghub-token -n demo
kubectl get secret ghub-token -o yaml -n demo
```

Decode:

```bash
kubectl get secret ghub-token -n demo -o jsonpath="{.data.token}" | base64 -d
```

---

# 12. Use Secret in Application

## 12.1 As environment variable

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
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

---

## 12.2 As volume

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

# 13. Security Improvements

## 13.1 Least Privilege IAM

```json
{
  "Effect": "Allow",
  "Action": [
    "secretsmanager:GetSecretValue",
    "secretsmanager:DescribeSecret"
  ],
  "Resource": "arn:aws:secretsmanager:ap-south-1:<ACCOUNT_ID>:secret:ghub-token*"
}
```

> If you use `dataFrom.find` to discover multiple secrets, also add
> `secretsmanager:ListSecrets` to the `Action` list.

---

## 13.2 Temporary Credentials (STS / AssumeRole)

`aws sts get-session-token` returns credentials that expire in 1–12 hours. A
long-running operator like ESO will lose access when they expire, so **do not**
use `get-session-token` for ESO.

For non-IRSA production setups, use a **dedicated IAM role and AssumeRole**
instead. The trust policy can allow another AWS principal (or cross-account) to
assume it, and ESO can refresh the assumed credentials automatically.

Example auth block for a role:

```yaml
auth:
  assumeRole: arn:aws:iam::<ACCOUNT_ID>:role/external-secrets-assume-role
```

For EKS, [IRSA](#14-irsa-production-concept) is preferred because it avoids storing any AWS credentials
in the cluster.

---

# 14. IRSA (Production Concept)

## 14.1 Why IRSA?

Avoid storing AWS credentials in cluster.

---

## 14.2 ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-sa
  namespace: external-secrets
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/external-secrets-role
```

---

## 14.3 Helm values to use the annotated ServiceAccount

```yaml
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/external-secrets-role
```

Or, if you create the ServiceAccount manually (above), set `serviceAccount.create: false`
and reference it here:

```yaml
serviceAccount:
  create: false
  name: external-secrets-sa
```

## 14.4 ClusterSecretStore (IRSA)

```yaml
auth:
  jwt:
    serviceAccountRef:
      name: external-secrets-sa
      namespace: external-secrets
```

---

## 14.5 Trust Policy

Replace `<OIDC_ID>` with the EKS cluster's OIDC provider ID and `<REGION>` with
your AWS region (e.g. `ap-south-1`).

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>:aud": "sts.amazonaws.com",
          "oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>:sub": "system:serviceaccount:external-secrets:external-secrets-sa"
        }
      }
    }
  ]
}
```

---

## 14.6 IRSA Flow

```
Pod → ServiceAccount → JWT Token
     → AWS STS (AssumeRoleWithWebIdentity)
     → IAM Role → Temporary Credentials
     → Access Secrets Manager
```

---

# 15. Why IRSA DOES NOT work on Minikube

| Requirement          | Minikube |
| -------------------- | -------- |
| OIDC Provider        | ❌        |
| AWS IAM Integration  | ❌        |
| Trusted Token Issuer | ❌        |

---

# Final Summary

## Minikube (Dev)

```
External Secrets → AWS (static or cross-account AssumeRole creds)
```

## EKS (Prod)

```
External Secrets → IRSA → IAM Role → AWS
```

---

# Key Takeaways

* ESO syncs external secrets into Kubernetes
* API version must match CRDs / chart version (`v1` ≥ chart v0.17.0)
* Plain vs JSON secrets handled differently
* Static creds work everywhere but less secure; AssumeRole is better, IRSA is best
* IRSA is the production-grade solution
* IRSA depends on AWS OIDC (not available in Minikube)

---

# Next Steps

* Integrate with ArgoCD (GitOps secrets)
* Add secret rotation handling
* Move to IRSA when using EKS
* Use SOPS / SealedSecrets for Git security **only for secrets that must live in Git**; ESO replaces them for AWS-sourced secrets

---
