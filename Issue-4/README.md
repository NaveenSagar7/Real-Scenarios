# SHOPNEST-5183 — deploy-bot RBAC & promo-banner-service

**Priority:** P1
**Component:** Kubernetes — RBAC / automated deploy job
**Status:** Resolved

---

## 🎫 The Ticket

**Company:** ShopNest (same org as SHOPNEST-4471).

**Setup:** `deploy-bot` — an internal tool replacing manual `kubectl apply` releases. Runs as a Kubernetes **Job**, using a dedicated **ServiceAccount** with tightly scoped **RBAC** (least privilege — no cluster-admin, no wildcard verbs), per a recent security review flagging over-privileged personal kubeconfigs. Its job: apply an updated Deployment manifest for `promo-banner-service` into the `shopnest-apps` namespace.

**What changed:** RBAC manifests (`Role`, `RoleBinding`, `ServiceAccount`) and the `deploy-bot` Job were written and applied for the first time this week.

**What happened:** The `deploy-bot` Job was triggered and immediately failed. Escalated rather than debugged internally, since "the security-hardening changes are the whole point and nobody wants to just grant cluster-admin to make the error go away."

**Objective:** Get `deploy-bot` to successfully apply the Deployment, **and** get the resulting `promo-banner-service` pods actually running — without widening RBAC beyond what's needed.

---

## 🚀 Deploy the Infra

```bash
kubectl apply -f namespace.yaml
kubectl apply -f rbac/
kubectl apply -f deploy-bot/target-manifest-configmap.yaml
```

This creates the `shopnest-apps` namespace, the ServiceAccount/Role/RoleBinding, and the ConfigMap holding the target Deployment manifest — environment setup, not part of the ticket itself.

**Trigger the ticket scenario:**
```bash
kubectl apply -f deploy-bot/job.yaml
```

---

## 🔍 Commands to Start Investigating

```bash
kubectl describe job deploy-bot -n shopnest-apps
kubectl get pods -n shopnest-apps
kubectl logs <deploy-bot-pod> -n shopnest-apps
kubectl get events -n shopnest-apps
```

**Setup note:** `deploy-bot` is a Job that runs `kubectl apply -f /manifests/deployment.yaml`. The manifest itself isn't baked into the Job — it's mounted from a **ConfigMap** (`promo-banner-manifest`), which holds the actual `promo-banner-service` Deployment YAML. The Job is just the runner; the ConfigMap is the actual source of what gets deployed, so a bug in the target app's manifest lives in the ConfigMap, not the Job.

---

## ✅ Solution

**Issue 1 — `deploy-bot` Job failed with RBAC Forbidden**
```
Forbidden: ... cannot get resource "deployments" in API group "apps"
```
`rbac/role.yaml` granted permissions under `apiGroups: [""]` (the core API group — Pods, Services, ConfigMaps), but `Deployment` belongs to the `apps` API group, not core. Not a missing-verb issue — a wrong-group issue, so the rule granted nothing for Deployments.

Fix:
```yaml
apiGroups: ["apps"]   # was [""]
```
No verbs or resources widened — least privilege preserved.

**Issue 2 — `promo-banner-service` pods stuck in `ImagePullBackOff`**
After the Job succeeded, the app pods still failed to pull their image. The Deployment manifest inside the ConfigMap referenced `naveen352/notification-service:v1` — a tag that was never actually pushed (only `latest` exists).

Fix: updated the image tag inside `deploy-bot/target-manifest-configmap.yaml` to `:latest`, then re-ran the Job so it re-applied the corrected manifest.

**Verification:**
```bash
kubectl get jobs.batch -n shopnest-apps          # deploy-bot: Complete, 1/1
kubectl get deployments.apps -n shopnest-apps    # promo-banner-service: 2/2 available
kubectl get pods -n shopnest-apps                # both app pods Running, 1/1 Ready
```

---

## 📎 Additional Notes

A successful Job (`Complete`, `1/1`) only proves `deploy-bot` itself ran without error — it doesn't guarantee the app it deployed is actually healthy. Always check the downstream Deployment/pods separately, not just the Job status.

# apiVersion: rbac.authorization.k8s.io/v1
# kind: Role
# metadata:
#   name: ns-admin-no-sts
#   namespace: NAMESPACE_NAME
# rules:
# - apiGroups: [""]
#   resources: ["pods","services","endpoints","persistentvolumeclaims","configmaps","secrets","events"]
#   verbs: ["*"]
# - apiGroups: ["apps"]
#   resources: ["deployments","replicasets","daemonsets","controllerrevisions"]
#   verbs: ["*"]
# - apiGroups: ["batch"]
#   resources: ["jobs","cronjobs"]
#   verbs: ["*"]
# - apiGroups: ["networking.k8s.io"]
#   resources: ["ingresses","networkpolicies"]
#   verbs: ["*"]
# - apiGroups: ["autoscaling"]
#   resources: ["horizontalpodautoscalers"]
#   verbs: ["*"]
# - apiGroups: ["policy"]
#   resources: ["poddisruptionbudgets"]
#   verbs: ["*"]
# - apiGroups: ["coordination.k8s.io"]
#   resources: ["leases"]
#   verbs: ["*"]
# # Note: Excluded 'statefulsets' deliberately. Add it back if needed.

# 3) Exec-only (support) within this namespace:
# apiVersion: rbac.authorization.k8s.io/v1
# kind: Role
# metadata:
#   name: exec-only
#   namespace: NAMESPACE_NAME
# rules:
# - apiGroups: [""]
#   resources: ["pods"]
#   verbs: ["get","list","watch"]
# - apiGroups: [""]
#   resources: ["pods/exec","pods/portforward","pods/log"]
#   verbs: ["create","get"]