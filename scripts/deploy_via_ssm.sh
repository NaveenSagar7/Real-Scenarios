#!/usr/bin/env bash
# Deploys the given image URI to the billing-invoice-service EC2 host by
# pushing a docker pull/run command through SSM Run Command (no SSH needed).
#
# Usage: ./deploy_via_ssm.sh <image_uri>
set -euo pipefail

IMAGE_URI="$1"
AWS_REGION="ap-south-1"

# Jenkins checks out a fresh workspace every build - .terraform/ isn't
# committed to git, so this directory has never been initialized here.
terraform -chdir=../terraform init -input=false

INSTANCE_ID=$(terraform -chdir=../terraform output -raw app_host_id)

echo "Deploying ${IMAGE_URI} to instance ${INSTANCE_ID}..."

aws ssm send-command \
  --region "${AWS_REGION}" \
  --instance-ids "${INSTANCE_ID}" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[
    \"aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin $(echo ${IMAGE_URI} | cut -d/ -f1)\",
    \"docker pull ${IMAGE_URI}\",
    \"docker stop billing-invoice-service || true\",
    \"docker rm billing-invoice-service || true\",
    \"docker run -d --name billing-invoice-service -p 8080:8080 -v /data/invoices:/data/invoices ${IMAGE_URI}\"
  ]" \
  --output text

echo "Command submitted to instance ${INSTANCE_ID}."
