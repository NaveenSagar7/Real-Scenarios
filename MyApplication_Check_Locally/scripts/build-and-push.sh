#!/usr/bin/env bash
# Build the daily-journal image and push it to the ECR repo created by
# Infra_For_MyApplication. Run from the MyApplication/ directory root.
#
# Usage:
#   AWS_REGION=ap-south-1 ./scripts/build-and-push.sh [image-tag]
#
# Requires: docker, aws cli configured, and the ECR repo already created
# (terraform apply in ../Infra_For_MyApplication).

set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
ECR_REPO_NAME="${ECR_REPO_NAME:-myapp}"
IMAGE_TAG="${1:-latest}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

echo "Logging in to ECR: ${ECR_URL}"
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "Building image ${ECR_URL}:${IMAGE_TAG}"
docker build -f docker/Dockerfile -t "${ECR_URL}:${IMAGE_TAG}" .

echo "Pushing ${ECR_URL}:${IMAGE_TAG}"
docker push "${ECR_URL}:${IMAGE_TAG}"

echo "Done. Update k8s/app/deployment.yaml image to: ${ECR_URL}:${IMAGE_TAG}"
