# shopnest-deploy-bot

RBAC-scoped deploy automation for `promo-banner-service`, running on Kubernetes.

## Prerequisites (one-time setup, before touching the ticket)

```bash
kubectl apply -f namespace.yaml
kubectl apply -f rbac/
kubectl apply -f deploy-bot/target-manifest-configmap.yaml
```

That creates the `shopnest-apps` namespace, the ServiceAccount/Role/RoleBinding, and the ConfigMap holding the target Deployment manifest. This is environment setup, not part of the ticket itself.

## Trigger the ticket scenario

```bash
kubectl apply -f deploy-bot/job.yaml
```

This runs the `deploy-bot` Job, which uses its scoped ServiceAccount to `kubectl apply` the `promo-banner-service` Deployment into `shopnest-apps`.

## Ticket: SHOPNEST-5183

The `deploy-bot` Job fails. Investigate using `kubectl describe job`, `kubectl logs`, and `kubectl get events` — least privilege must be preserved (no `cluster-admin`, no wildcard verbs/resources) while fixing whatever's actually broken.

Once `deploy-bot` succeeds, confirm `promo-banner-service` pods actually come up healthy — a successful Job doesn't guarantee the app it deployed is actually running.


# SHOPNEST-5183 — Root Cause & Fix

**Setup:** `deploy-bot` is a Kubernetes Job that runs `kubectl apply -f /manifests/deployment.yaml`, using a scoped ServiceAccount (`deploy-bot-sa`). The manifest it applies isn't baked into the Job itself — it's mounted from a **ConfigMap** (`promo-banner-manifest`), which holds the actual `promo-banner-service` Deployment YAML as a file. The Job is just the runner; the ConfigMap is the actual source of what gets deployed — so any bug in the target app's manifest lives in the ConfigMap, not the Job.

---

## Issue 1: `deploy-bot` Job failed — RBAC Forbidden

**How found:** `kubectl logs` on the failed pod showed:
```
Forbidden: ... cannot get resource "deployments" in API group "apps"
```

**Root cause:** `rbac/role.yaml` granted permissions under `apiGroups: [""]` (the core API group — Pods, Services, ConfigMaps, etc.), but `Deployment` belongs to the `apps` API group, not core. The rule was pointed at the wrong group entirely, so it effectively granted nothing for Deployments — not a missing-verb issue, a wrong-group issue.

**Fix:**
```yaml
apiGroups: ["apps"]   # was [""]
```
No verbs or resources were widened — least privilege preserved.

---

## Issue 2: `promo-banner-service` pods stuck in `ImagePullBackOff`

**How found:** After the Job succeeded, `kubectl get pods` showed the app pods failing to pull their image.

**Root cause:** The Deployment manifest inside the ConfigMap referenced `naveen352/notification-service:v1` — a tag that was never actually pushed to Docker Hub (only `latest` exists).

**Fix:** Updated the image tag inside `deploy-bot/target-manifest-configmap.yaml` to `naveen352/notification-service:latest`, then re-ran the Job so it re-applied the corrected manifest.

---

## Verification

```bash
kubectl get jobs.batch -n shopnest-apps          # deploy-bot: Complete, 1/1
kubectl get deployments.apps -n shopnest-apps    # promo-banner-service: 2/2 available
kubectl get pods -n shopnest-apps                # both app pods Running, 1/1 Ready
```

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