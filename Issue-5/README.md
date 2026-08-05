# transaction-reconciler

Node.js batch job that reconciles pending transactions and writes a log to disk. Built as a multi-stage Docker image.

## Prerequisites

Just Docker installed locally (Docker Desktop or Docker Engine). No cluster, no cloud account, nothing else to set up.

## Build

```bash
docker build -t transaction-reconciler:latest .
```

## Run

```bash
docker run --rm transaction-reconciler:latest
```

## Ticket: PAYFLOW-4402

The image builds successfully with no errors, but running the container fails. Investigate using `docker run` output and `docker logs` (if running detached). Keep the multi-stage build — do not revert to a single-stage Dockerfile.


# PAYFLOW-4402 — Findings & Learnings

## Bug 1: Missing `node_modules`
**Found via:** `docker run` → `Error: Cannot find module 'dayjs'`
**Cause:** Final stage never copied `node_modules` from the builder stage at all.
**Fix:** Added `COPY --from=builder /build/node_modules ./node_modules`.

## Bug 2: Copied contents instead of the folder
**Found via:** Same error persisted after adding the copy line.
**Cause:** `COPY --from=builder /build/node_modules/ ./` copies the *contents* of `node_modules` loose into `/app`, not the folder itself. Node requires a literal folder named `node_modules` to resolve packages.
**Fix:** Named the destination explicitly — `./node_modules` instead of `./`.

## Bug 3: Wrong relative path in app code
**Found via:** `ENOENT: no such file or directory, open '/output/reconcile.log'`
**Cause:** `path.join(__dirname, "..", "output")` walked up one level too many — resolved to `/output` instead of `/app/output`, since `__dirname` is `/app` inside the container.
**Fix:** Removed the extra `".."` — `path.join(__dirname, "output")`.

## Bug 4: Directory owned by root, process runs as non-root
**Found via:** `EACCES: permission denied, open '/app/output/reconcile.log'`
**Cause:** `/app/output` was created with `RUN mkdir` while still root, then `USER appuser` switched afterward — ownership doesn't retroactively change.
**Fix:** `COPY --chown=appuser:appgroup` on all copied files, and explicit `chown` on the created output directory.

---

## Learnings

- **A successful `docker build` proves nothing about runtime correctness.** Always `docker run` after building, especially after Dockerfile changes.
- **Multi-stage builds silently drop anything you forget to `COPY --from=builder`.** `node_modules` is the most common casualty — it's easy to remember source files and forget dependencies.
- **`COPY src/ ./` vs `COPY src ./dest`** behave differently — a trailing slash on the source (or a `./` destination) copies *contents*, not the folder itself. This matters a lot for `node_modules`, since Node needs the literal folder name.
- **Path bugs can hide inside app code, not just the Dockerfile.** `__dirname`-relative paths written and tested outside a container can resolve to a completely different location once the app's actual working directory changes inside the image.
- **Ownership must be set explicitly for non-root containers.** Anything created or copied before `USER <non-root>` is `root`-owned by default; switching users afterward doesn't retroactively fix permissions. Use `COPY --chown=...` or an explicit `chown` before dropping privileges.

##New Dockerfile

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

COPY --from=builder /build/node_modules/ /app/node_modules/
COPY --from=builder /build/index.js ./
COPY --from=builder /build/reconcile.js ./


#RUN chown -R appuser:appgroup /app/index.js
USER appuser
CMD ["node", "index.js"]