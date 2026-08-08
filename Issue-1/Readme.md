# SHOPNEST-4471 — cart-service on EKS

**Priority:** P2
**Component:** `cart-service` (Node.js/Express) / EKS
**Status:** Resolved

---

## 🎫 The Ticket

**Company:** ShopNest — mid-size e-commerce platform (flash-sale + regular catalog checkout flows).

**Service:** `cart-service` — owns the "add to cart" / "get cart" APIs. Talks to a Postgres RDS instance, exposes `/healthz` for liveness/readiness.

**What changed:** `cart-service` was just migrated off a legacy EC2 Auto Scaling Group onto EKS — the first Helm-based release of this service. The old EC2 setup used a `.env` file baked by Ansible; on EKS, config is now supposed to flow through a `ConfigMap`.

**What happened:** Release was deployed to the `shopnest-prod` namespace. Within minutes, on-call got paged: `ALB 5xx rate > threshold` and a `cart-service` pod restart count alert. A rollback attempt didn't fully resolve it, so traffic was temporarily pointed back at the legacy EC2 target group while this ticket gets the actual EKS-side root cause fixed.

**Objective:** Get `cart-service` running correctly and reachable on EKS in `shopnest-prod`, end to end — pods Ready, Service has endpoints, traffic actually routes through. Not told what's wrong or how many issues there are — investigate like a real incident.

---

## 🚀 Deploy the Infra

```bash
kubectl create namespace shopnest-prod
helm upgrade --install cart-service ./helm/cart-service -n shopnest-prod
```

Cluster needs to be able to pull `naveen352/issue-1:1.0` from Docker Hub (public image, no auth needed).

Confirm Helm's own view of the release:
```bash
helm status cart-service -n shopnest-prod
```
⚠️ `STATUS: deployed` only means the YAML was accepted by the API server — it does **not** mean the app is healthy. Never treat this alone as "it's working."

---

## 🔍 Commands to Start Investigating

```bash
# Are pods even scheduled and running?
kubectl get pods -n shopnest-prod
kubectl describe pod <pod-name> -n shopnest-prod
kubectl logs <pod-name> -n shopnest-prod

# Even if pods look fine, can the Service actually reach them?
kubectl get endpoints cart-service -n shopnest-prod
kubectl get svc cart-service -n shopnest-prod -o yaml | grep -A3 selector
kubectl get pods -n shopnest-prod --show-labels
```

**Why check endpoints even when pods look fine:** `kubectl get pods` only shows pod health, not connectivity. A Service can be perfectly schema-valid and still route to **zero** pods if its `selector` doesn't match any pod's `labels`. `kubectl get endpoints` is the only way to know if the Service actually has anywhere to send traffic.

---

## ✅ Solution

Two unrelated bugs, both the same failure pattern: **hand-typed identifiers that have to match exactly across two files, with nothing enforcing that they do.**

**Bug #1 — ConfigMap key mismatch → `CreateContainerConfigError`**
`deployment.yaml`'s `configMapKeyRef.key` was `DB_HOST`; `configmap.yaml` actually defined the key as `DATABASE_HOST`.
```yaml
env:
  - name: DB_HOST                # app reads process.env.DB_HOST — keep this name
    valueFrom:
      configMapKeyRef:
        name: cart-service-config
        key: DATABASE_HOST       # fix: must match the ConfigMap's real key
```

**Bug #2 — Service selector mismatch → Endpoints stayed `<none>`**
Pods `Running`/`Ready`, but completely unreachable — no errors anywhere. `service.yaml`'s selector used `app.kubernetes.io/name`; pods only carried the label `app`.
```yaml
spec:
  selector:
    app: cart-service   # fix: match deployment.yaml's actual pod labels
```
(Fixed on the Service side, not the Deployment — `matchLabels` is immutable once created, and was already internally consistent.)

**After any fix**, re-apply forward, don't roll back:
```bash
helm upgrade --install cart-service ./helm/cart-service -n shopnest-prod
kubectl rollout status deployment/cart-service -n shopnest-prod
kubectl get endpoints cart-service -n shopnest-prod
```

---

## 📎 Additional Notes

**Why neither `helm upgrade` nor `kubectl apply` caught either bug:** both only validate YAML syntax and API schema — not cross-resource references. A ConfigMap key that doesn't exist, or a selector matching zero pods, is still 100% schema-valid Kubernetes. Only runtime behavior (pod events, endpoint lists) reveals the break.

**Prevention, for real (not just "be more careful"):**
- A shared label helper (`_helpers.tpl`) so labels are defined **once** and `include`d in both the Deployment and the Service — makes Bug #2 structurally impossible to repeat.
- `helm template` in CI, before touching a cluster, so someone (or a script) can inspect the actual rendered selectors/keys.
- Policy-as-code in CI (`conftest`/OPA, Kubescape, Datree) asserting rules like "every `configMapKeyRef.key` must exist in a ConfigMap in this chart."
- A CI stage that deploys to staging and checks `kubectl get endpoints` is non-empty before promoting — with auto-`helm rollback` on failure.

The real lesson: "the engineer made a typo" isn't an actionable root cause on its own — the same mistake will happen again with the next person who touches this chart. The fix is making the *system* catch it in CI, not relying on carefulness.