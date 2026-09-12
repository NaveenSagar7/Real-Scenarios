#!/usr/bin/env bash
# Basic smoke test against a running meter-reading-service endpoint.
# Usage: ./smoke_test.sh http://<alb-or-portforward-host>:<port>
set -euo pipefail

BASE_URL="${1:?Usage: smoke_test.sh <base_url>}"

echo "-> GET /health"
curl -fsS -w "\nHTTP %{http_code}\n" "${BASE_URL}/health"

echo "-> POST /ingest"
curl -fsS -w "\nHTTP %{http_code}\n" \
  -X POST "${BASE_URL}/ingest" \
  -H "Content-Type: application/json" \
  -d '{"meter_id": "MTR-100234", "reading_kwh": 452.7}'
