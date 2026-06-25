# Force Deleting Stuck Kubernetes Resources

Resources in Kubernetes can get stuck in a `Terminating` state when they have finalizers that are never cleared — usually because the controller managing them is gone or broken. This guide covers how to force delete them.

---

## Prerequisites

- `kubectl` configured and connected to your cluster
- Sufficient RBAC permissions to patch and delete resources

---

## 1. Remove Finalizers from a Custom Resource

When a custom resource (CRD) is stuck, its controller may have been deleted before it could clean up. Patch the finalizers to an empty array to unblock deletion.

```bash
kubectl patch <resource-type> <resource-name> -n <namespace> \
  -p '{"metadata":{"finalizers":[]}}' --type=merge
```

Then delete it:

```bash
kubectl delete <resource-type> <resource-name> -n <namespace>
```

---

## 2. Force Delete a Namespace

```bash
kubectl delete namespace <namespace> --grace-period=0
```

> If the namespace is still stuck after this, proceed to Step 4.

---

## 3. Remove Finalizers from an ArgoCD Application

ArgoCD apps use finalizers to trigger resource cleanup on deletion. If ArgoCD itself is being removed or the app is broken, patch the finalizer out first.

```bash
kubectl patch app <app-name> -n argocd \
  --type='json' \
  -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
```

Then delete the app:

```bash
kubectl delete app <app-name> -n argocd
```

---

## 4. Force Delete a Stuck Namespace via Kubernetes API

Use this as a last resort when a namespace is stuck in `Terminating` and nothing else works. It directly calls the Kubernetes API to clear the finalizers.

**Start the kubectl proxy:**
```bash
kubectl proxy &
```

**Call the finalize endpoint:**
```bash
curl -X PUT http://127.0.0.1:8001/api/v1/namespaces/<namespace>/finalize \
  -H "Content-Type: application/json" \
  --data-binary '{
    "apiVersion": "v1",
    "kind": "Namespace",
    "metadata": {
      "name": "<namespace>",
      "finalizers": []
    }
  }'
```

Replace `<namespace>` with the actual namespace name.

---

## Quick Reference

| Situation | Command |
|---|---|
| Custom resource stuck | `kubectl patch <type> <name> -p '{"metadata":{"finalizers":[]}}'` |
| Namespace stuck | `kubectl delete namespace <name> --grace-period=0` |
| ArgoCD app stuck | `kubectl patch app <name> --type=json -p '[{"op":"remove","path":"/metadata/finalizers"}]'` |
| Namespace stuck via API | `kubectl proxy` + `curl PUT .../finalize` |

---

## Why This Happens

Finalizers are Kubernetes' way of ensuring cleanup happens before a resource is deleted. When the controller responsible for that cleanup is gone (uninstalled, crashed, or misconfigured), the finalizer never gets removed and the resource hangs indefinitely. The fix is always the same: manually clear the finalizers.