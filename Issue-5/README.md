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
