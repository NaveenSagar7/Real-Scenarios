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
