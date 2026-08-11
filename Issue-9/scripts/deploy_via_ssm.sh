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

COMMAND_ID=$(aws ssm send-command \
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
  --query "Command.CommandId" \
  --output text)

echo "Command ${COMMAND_ID} submitted to instance ${INSTANCE_ID}. Waiting for result..."

aws ssm wait command-executed \
  --region "${AWS_REGION}" \
  --command-id "${COMMAND_ID}" \
  --instance-id "${INSTANCE_ID}" || true

STATUS=$(aws ssm get-command-invocation \
  --region "${AWS_REGION}" \
  --command-id "${COMMAND_ID}" \
  --instance-id "${INSTANCE_ID}" \
  --query "Status" \
  --output text)

echo "----- SSM command output -----"
aws ssm get-command-invocation \
  --region "${AWS_REGION}" \
  --command-id "${COMMAND_ID}" \
  --instance-id "${INSTANCE_ID}" \
  --query "{StandardOutput:StandardOutputContent,StandardError:StandardErrorContent}" \
  --output text
echo "-------------------------------"

if [ "${STATUS}" != "Success" ]; then
  echo "Deploy command finished with status: ${STATUS} - failing the build."
  exit 1
fi

echo "Deploy command succeeded on instance ${INSTANCE_ID}."
