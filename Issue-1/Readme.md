# cart-service — EKS Deployment Runbook & Incident Notes

**Ticket:** SHOPNEST-4471
**Component:** cart-service (Node.js/Express) on Kubernetes
**Image:** `naveen352/issue-1:1.0`
**Status:** Resolved

This document is both a **run guide** (how to deploy this service on any Kubernetes cluster) and an **incident record** (what broke, why, how it was found, and how to stop it from happening again). Read this top to bottom if you're seeing this service for the first time — or years from now trying to remember why these files look the way they do.

---

## 1. Prerequisites

- A working Kubernetes cluster and `kubectl` context pointed at it
- `helm` installed (v3+)
- Cluster must be able to pull the image `naveen352/issue-1:1.0` from Docker Hub (public image, no registry auth needed)

---

## 2. Deploy From Scratch

### Step 1 — Create the namespace

The chart assumes namespace `shopnest-prod` already exists (Helm does not create namespaces by default unless you pass `--create-namespace`).

```bash
kubectl create namespace shopnest-prod
```

Optional — set it as your default namespace so you don't need `-n shopnest-prod` on every command:

```bash
kubectl config set-context --current --namespace=shopnest-prod
```

### Step 2 — Install the chart

```bash
helm upgrade --install cart-service ./helm/cart-service -n shopnest-prod
```

`upgrade --install` is used instead of `helm install` because it's idempotent — safe to re-run whether this is the first deploy or the hundredth. Every successful apply creates a new **revision**.

### Step 3 — Confirm Helm's view of the release

```bash
helm status cart-service -n shopnest-prod
helm history cart-service -n shopnest-prod
```

⚠️ **`STATUS: deployed` only means the YAML was accepted by the API server.** It does **not** mean the application is actually healthy. Never treat `helm status` as your "it's working" signal — always verify at the pod level next.

---

## 3. Verifying Health (the checks that actually matter)

Run these in order. Each one rules out a different failure category.

```bash
# 1. Are pods even scheduled and running?
kubectl get pods -n shopnest-prod

# 2. If a pod isn't Running/Ready, get the event history
kubectl describe pod <pod-name> -n shopnest-prod

# 3. If a pod is Running but the app inside is misbehaving, check its logs
kubectl logs <pod-name> -n shopnest-prod

# 4. Even if pods are Running, confirm the Service can actually route to them
kubectl get endpoints cart-service -n shopnest-prod
kubectl get svc cart-service -n shopnest-prod -o yaml | grep -A3 selector
kubectl get pods -n shopnest-prod --show-labels
```

**Why step 4 matters even when pods look fine:** `kubectl get pods` shows pod health, not connectivity. A Service can exist, be perfectly schema-valid, and still route to **zero** pods if its `selector` doesn't match any pod's `labels`. The only way to know if a Service actually has somewhere to send traffic is `kubectl get endpoints <svc-name>`. If that shows `<none>`, the Service is broken *regardless* of what `kubectl get pods` says.

---

## 4. What Was Actually Broken (root cause, in order found)

This release shipped with **two separate, unrelated bugs**. Both are examples of the same underlying failure category: **hand-typed identifiers that must match exactly across two different files, with nothing enforcing that they do.**

### Bug #1 — ConfigMap key mismatch (`CreateContainerConfigError`)

**Symptom:** `kubectl describe pod` showed:
```
Warning  Failed  ...  couldn't find key DB_HOST in ConfigMap shopnest-prod/cart-service-config
```
Pod never left `ContainerCreating` / `CreateContainerConfigError`.

**Where:** `helm/cart-service/templates/deployment.yaml`, in the container's `env` block, `configMapKeyRef.key`.

**The mismatch:**
| File | What it defines |
|---|---|
| `configmap.yaml` | Key is `DATABASE_HOST` (from `.Values.config.DATABASE_HOST`) |
| `deployment.yaml` | Env var `DB_HOST` tries to read `configMapKeyRef.key: DB_HOST` |

The app code (`index.js`) expects an environment variable literally named `DB_HOST` — that part was correct. The bug was that the **key used to look up the value inside the ConfigMap** was also written as `DB_HOST`, but no such key exists there — only `DATABASE_HOST` does.

**Fix applied:** In `deployment.yaml`, keep the env var **name** as `DB_HOST` (app needs that exact name), but change `configMapKeyRef.key` to `DATABASE_HOST` to match what's actually in the ConfigMap.

```yaml
env:
  - name: DB_HOST                # name the app reads via process.env.DB_HOST — do not change
    valueFrom:
      configMapKeyRef:
        name: cart-service-config
        key: DATABASE_HOST       # must match the ConfigMap's actual key, not the env var name
```

### Bug #2 — Service selector / pod label mismatch (Endpoints stayed empty)

**Symptom:** All 3 pods `Running`, `1/1 Ready`, zero restarts — looked completely healthy. But:
```
kubectl get endpoints cart-service -n shopnest-prod
NAME           ENDPOINTS   AGE
cart-service   <none>      20m
```
Nothing could reach the pods through the Service — not because anything was crashing, but because the Service had no idea the pods existed.

**Where:** `helm/cart-service/templates/service.yaml`, `spec.selector`.

**The mismatch:**
| Resource | Label key used |
|---|---|
| Pod template (in `deployment.yaml`) | `app: cart-service`, `tier: backend` |
| Service selector (in `service.yaml`) | `app.kubernetes.io/name: cart-service` |

`app` and `app.kubernetes.io/name` are **completely different keys**, even though the value (`cart-service`) is identical in both. Kubernetes label selectors match on key **and** value together — matching the value with the wrong key is the same as matching nothing at all. No pod on the cluster had a label with the key `app.kubernetes.io/name`, so the Service's selector matched zero pods, and `Endpoints` stayed `<none>` forever, with no error, no event, no warning anywhere. Unlike Bug #1, this one is **completely silent** — nothing crashes, nothing restarts, no log entry. The only way to catch it is to explicitly check `kubectl get endpoints`.

**Fix applied:** Changed the Service selector to match the actual key already used on the pods (`app`), rather than changing the Deployment — because:
- The Deployment's `spec.selector.matchLabels` is **immutable** after creation; trying to change it fails the apply.
- The Deployment's `matchLabels` and pod template `labels` were already internally consistent (`app: cart-service` in both) — the Service was the only outlier.

```yaml
spec:
  selector:
    app: cart-service   # must match deployment.yaml's pod template labels exactly
```

**Rule of thumb going forward:** when a Service selector and a Deployment's pod labels must match, always check which side is *load-bearing elsewhere* (ReplicaSet `matchLabels` is immutable and drives pod ownership — treat that as the source of truth, and make the Service conform to it, not the other way around).

---

## 5. Commands To Run After Any Fix

Whenever you edit a template file (`deployment.yaml`, `service.yaml`, `configmap.yaml`, etc.) directly, you are producing a **new desired state** — apply it forward, don't roll back:

```bash
helm upgrade --install cart-service ./helm/cart-service -n shopnest-prod
kubectl rollout status deployment/cart-service -n shopnest-prod
kubectl get pods -n shopnest-prod
kubectl get endpoints cart-service -n shopnest-prod
```

`helm rollback` is for going **back** to a previously working revision — it is the wrong tool here, since it would just take you back to an *older broken state*, not forward to your fix. Only use `helm rollback` when the previous revision is known-good and you need to revert quickly (e.g., a bad prod release, not a chart you're actively fixing).

---

## 6. Why Neither Helm Nor Kubernetes Caught Either Bug

This is the part worth actually understanding, not just memorizing the fix.

`helm upgrade`, `helm install`, and `kubectl apply` only validate:
- **YAML syntax** — is it well-formed?
- **API schema** — does the object have the right fields/types for its `kind`?

They do **not** validate:
- Whether a `configMapKeyRef.key` actually exists in the referenced ConfigMap (that's resolved by the **kubelet at container start**, not at apply time)
- Whether a Service's `selector` matches any pod's `labels` (a Service with zero matching pods is 100% valid Kubernetes — sometimes that's even intentional, e.g., a Service created before its pods exist)

Both bugs are examples of **cross-resource referential integrity** — a relationship between two separate objects that Kubernetes does not enforce, because objects are deliberately loosely coupled (labels/selectors and key references are just string matching, not foreign keys with constraints). Schema-valid YAML can still be logically broken, and only runtime behavior — pod events, endpoint lists — reveals that.

---

## 7. How To Prevent This Class Of Bug (shift-left, not just "be careful")

"The engineer made a typo" is true but not an actionable fix — the same mistake will happen again with the next person who edits this chart. The goal is to make the *system* catch it, not rely on human carefulness alone. Layers, roughly in order of where they sit in the pipeline:

1. **Shared label helper in the chart itself (`_helpers.tpl`)** — the actual structural fix. Define labels **once**:
   ```yaml
   {{- define "cart-service.selectorLabels" -}}
   app: {{ .Chart.Name }}
   {{- end }}
   ```
   Then `include` it in both `deployment.yaml`'s pod template labels/`matchLabels` **and** `service.yaml`'s selector. If there's only one place the label is ever typed, the two can never drift apart. This alone would have made Bug #2 structurally impossible.

2. **`helm template` in CI, before any cluster is touched** — renders the final manifests so a human or a script can inspect the *actual* selectors/keys/env vars that will be applied, not just the templated source.

3. **Policy-as-code checks in CI** — tools like `conftest` (OPA/Rego), Kubescape, or Datree can assert custom rules such as "every `configMapKeyRef.key` must exist in a ConfigMap defined in this chart" or "every Service selector must match the labels of at least one Deployment in this chart." This is exactly the class of bug these tools exist to catch, and it catches it in a PR, not in prod.

4. **`kubectl apply --dry-run=server`** against a real (non-prod) cluster in CI — catches schema errors, but note this does **not** catch either of these two bugs, since the API server itself doesn't validate cross-resource references either. Still worth having as a baseline gate.

5. **A CI/CD pipeline stage that deploys to a lower environment and checks actual runtime health before promoting** — this is the most reliable catch-all, because it tests real behavior instead of static config. A pipeline for this service should, after every deploy to `staging`:
   ```bash
   kubectl rollout status deployment/cart-service -n <env> --timeout=90s
   kubectl get endpoints cart-service -n <env> -o jsonpath='{.subsets}' | grep -q . || exit 1
   ```
   If either check fails, the pipeline should **stop and not promote to prod** — and ideally auto-`helm rollback` the environment it just broke back to the last known-good revision, rather than leaving it in a broken state for someone to find manually.

6. **Automatic rollback on failed rollout** — `kubectl rollout status` has a timeout; if the rollout doesn't succeed in that window (pods never reach Ready, or Endpoints stay empty), the pipeline should trigger:
   ```bash
   helm rollback cart-service -n <env>
   ```
   rather than leaving a half-broken release live. This turns "an engineer has to notice and fix it at 2am" into "the pipeline caught it and reverted automatically before it ever reached users."

**The mental model to keep:** assume this exact mistake (hand-typed key/label typo) will happen again — because it will, with any engineer, eventually. The question that actually prevents repeat incidents isn't "how do we stop people from making typos," it's "how do we make sure a typo like this is caught in a PR or a CI stage, instead of paging on-call in production." That's the difference between a one-off fix and an actual improvement to how this service ships.

---

## 8. Quick Reference — Full Command Sequence

```bash
# Setup
kubectl create namespace shopnest-prod

# Deploy
helm upgrade --install cart-service ./helm/cart-service -n shopnest-prod
helm status cart-service -n shopnest-prod

# Verify
kubectl get pods -n shopnest-prod
kubectl describe pod <pod-name> -n shopnest-prod
kubectl logs <pod-name> -n shopnest-prod
kubectl get endpoints cart-service -n shopnest-prod
kubectl get svc cart-service -n shopnest-prod -o yaml | grep -A3 selector
kubectl get pods -n shopnest-prod --show-labels

# After any chart fix — re-apply forward, don't rollback
helm upgrade --install cart-service ./helm/cart-service -n shopnest-prod
kubectl rollout status deployment/cart-service -n shopnest-prod

# Only if you need to revert to a previous good release
helm rollback cart-service -n shopnest-prod
```