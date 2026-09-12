#!/usr/bin/env bash
# One-time bootstrap: creates the remote Terraform backend (S3 + DynamoDB),
# then initializes and applies the main infra stack against that backend.
set -euo pipefail

cd "$(dirname "$0")/../terraform/backend"
terraform init
terraform apply -auto-approve

STATE_BUCKET=$(terraform output -raw state_bucket)
LOCK_TABLE=$(terraform output -raw lock_table)

cd ../infra
terraform init \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="key=meter-reading-service/infra.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="dynamodb_table=${LOCK_TABLE}"

echo "Backend configured. Review the plan, then run: terraform apply"
terraform plan
