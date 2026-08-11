#!/usr/bin/env bash
# Usage: ./smoke_test.sh <host-public-ip>
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <host-public-ip>"
  exit 1
fi

HOST="$1"

echo "GET /healthz ..."
curl -sS -o /dev/null -w "HTTP %{http_code}\n" "http://${HOST}:8080/healthz"

echo "POST /api/v1/invoices ..."
curl -sS -X POST "http://${HOST}:8080/api/v1/invoices" \
  -H 'Content-Type: application/json' \
  -d '{"customer_id": "CUST-1042", "amount_due": 1899.50}' \
  -w "\nHTTP %{http_code}\n"
