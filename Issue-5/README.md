# PAYFLOW-4402 — transaction-reconciler Docker build

**Priority:** P2
**Component:** Docker — `transaction-reconciler` service
**Status:** Resolved

---

## 🎫 The Ticket

**Company:** PayFlow (same org as PAYFLOW-2298, PAYFLOW-3107).

**Service:** `transaction-reconciler` — a Node.js batch job that reconciles pending transactions against a settlement file and writes a reconciliation log to disk. Run as a one-off container via `docker run`, not yet on Kubernetes.

**What changed:** Switched from a single-stage Dockerfile to a **multi-stage build**, to keep the production image slim (a DevSecOps requirement — smaller attack surface, no build tools/dev dependencies shipping to prod). Written by a backend engineer, merged after it "built fine locally."

**What happened:** CI builds the image successfully every time — `docker build` completes with no errors. But actually **running** the container fails. Never caught before merge, because nobody ran the container after switching to multi-stage — only the build step was checked.

**Objective:** Get `transaction-reconciler` to build **and run successfully**, producing a working reconciliation log — while **keeping the multi-stage build** (no reverting to single-stage).

---

## 🚀 Deploy / Setup

Just Docker installed locally — no cluster, no cloud account.

```bash
docker build -t transaction-reconciler:latest .
docker run --rm transaction-reconciler:latest
```

---

## 🔍 Commands to Start Investigating

```bash
# See what actually landed inside the image
docker run --rm --entrypoint sh transaction-reconciler:latest -c "ls -la /app"
docker run --rm --entrypoint sh transaction-reconciler:latest -c "ls -la /app/node_modules"

# Run it for real and read the actual error
docker run --rm transaction-reconciler:latest
```

---

## ✅ Solution

Four issues, found one at a time as each fix revealed the next:

**Bug 1 — Missing `node_modules`.** `Error: Cannot find module 'dayjs'`. Final stage never copied `node_modules` from the builder stage at all. Fix: added `COPY --from=builder /build/node_modules ./node_modules`.

**Bug 2 — Copied contents instead of the folder.** Same error persisted. `COPY --from=builder /build/node_modules/ ./` copies the *contents* of `node_modules` loose into `/app`, not the folder itself — Node needs a literal folder named `node_modules` to resolve packages. Fix: named the destination explicitly (`./node_modules`, not `./`).

**Bug 3 — Wrong relative path in app code.** `ENOENT: /output/reconcile.log`. `path.join(__dirname, "..", "output")` walked up one level too many — resolved to `/output` instead of `/app/output`, since `__dirname` is `/app` inside the container. Fix: removed the extra `".."` — `path.join(__dirname, "output")`.

**Bug 4 — Directory owned by root, process runs as non-root.** `EACCES: permission denied`. `/app/output` was created via `RUN mkdir` while still root, then `USER appuser` switched afterward — ownership doesn't retroactively change. Fix: explicit `chown` on the output directory and `COPY --chown=appuser:appgroup` on copied files, before dropping to the non-root user.

**Final working Dockerfile:**
```dockerfile
# ---- Build stage ----
FROM node:20-alpine AS builder
WORKDIR /build
COPY app/package.json ./
RUN npm install --production
COPY app/ .

# ---- Final stage ----
FROM node:20-alpine AS final

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app
RUN mkdir -p /app/output && chown -R appuser:appgroup /app/

COPY --from=builder --chown=appuser:appgroup /build/node_modules/ /app/node_modules/
COPY --from=builder --chown=appuser:appgroup /build/index.js ./
COPY --from=builder --chown=appuser:appgroup /build/reconcile.js ./

USER appuser
CMD ["node", "index.js"]
```

---

## 📎 Learnings

- **A successful `docker build` proves nothing about runtime correctness.** Always `docker run` after building, especially after Dockerfile changes.
- **Multi-stage builds silently drop anything you forget to `COPY --from=builder`.** `node_modules` is the most common casualty.
- **`COPY src/ ./` vs `COPY src ./dest`** behave differently — a trailing slash on the source (or a `./` destination) copies *contents*, not the folder itself.
- **Path bugs can hide inside app code, not just the Dockerfile.** `__dirname`-relative paths written and tested outside a container can resolve to a completely different location inside the image.
- **Ownership must be set explicitly for non-root containers.** Anything created/copied before `USER <non-root>` is `root`-owned by default; switching users afterward doesn't retroactively fix permissions.