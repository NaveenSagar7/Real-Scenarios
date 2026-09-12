# Issue-10 — VANTRA-4581: meter-reading-ingest-service unhealthy after EKS launch

## 🎫 Ticket

**Project:** Vantra Utility Billing Platform
**Ticket:** VANTRA-4581
**Type:** Production Incident
**Priority:** P2
**Reported by:** On-call SRE (paged via CloudWatch/ALB alarm)
**Component:** meter-reading-ingest-service / Shared EKS Platform

**Summary:** meter-reading-ingest-service unreachable through ALB after first EKS deployment; upstream writes failing.

**Description:**

Vantra's field-device gateway team has been batching smart-meter reads and POSTing
them to the legacy `billing-invoice-service` host directly, which does not scale
and has no schema validation. This sprint, the Platform team stood up Vantra's
first shared EKS cluster (`vantra-shared-eks`, ap-south-1) so new services can be
deployed with proper autoscaling, IRSA-based AWS access (no static credentials),
and ALB Ingress instead of hand-managed EC2 + Nginx.

`meter-reading-ingest-service` is the first service onboarded to this cluster. It
is a small Flask service with two responsibilities:

- `POST /ingest` — writes the raw payload to an S3 bucket (`raw/<meter_id>/<reading_id>.json`)
  and a normalized record to a DynamoDB table, using AWS credentials obtained via
  IRSA (no access keys baked into the pod).
- `GET /health` — liveness/readiness check.

Terraform provisions the VPC, EKS cluster, IRSA role for the service, the ECR
repository, the S3/DynamoDB data stores, and the AWS Load Balancer Controller.
A GitHub Actions workflow builds the image, pushes it to ECR, and deploys the
Helm chart on every push to `main`.

The initial rollout was merged and the GitHub Actions workflow **completed
successfully** (green checkmark, all steps passed, `helm upgrade --install`
reported deployed). Despite that, the on-call engineer was paged 20 minutes
later:

- Hitting the ALB DNS name for `meter-reads.vantra.internal` returns `502 Bad
  Gateway`.
- The target group associated with the Ingress shows **0 healthy targets**.
- `kubectl get pods -n vantra-billing` shows a mix of pod states, and pods that
  do reach `Running` are logging repeated failures whenever `/ingest` is called.
- Nothing was changed manually in the AWS console or in-cluster — everything
  that exists was created by Terraform, Helm, and the GitHub Actions pipeline
  in this repository.

Field-device gateway team is blocked from cutting over until this is resolved.

## 🚀 Objective

Get `meter-reading-ingest-service` fully healthy and serving traffic through the
ALB, with successful end-to-end writes to S3 and DynamoDB via IRSA — using only
the Terraform, Helm, and GitHub Actions already defined in this repository (fix
what's wrong, don't work around it manually in the console or with `kubectl
edit` patches that Terraform/Helm will just overwrite on the next apply).

You are not told how many things are wrong, or where. Investigate like you
would a real page.

## 📁 Repository Structure

```
Issue-10/
├── app/
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── helm/
│   └── meter-reading-service/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── serviceaccount.yaml
│           └── ingress.yaml
├── terraform/
│   ├── backend/        # bootstrap: S3 state bucket + DynamoDB lock table
│   └── infra/           # VPC, EKS, IRSA, ECR, S3/DynamoDB data stores, ALB controller
├── .github/workflows/deploy.yml
├── scripts/
│   ├── bootstrap.sh     # one-time: creates backend, initializes infra stack
│   └── smoke_test.sh    # hits /health and /ingest on a given base URL
└── README.md
```

## 🛠️ Deploy

1. `aws configure` / confirm your CLI is pointed at the account you want to use,
   region `ap-south-1`.
2. `./scripts/bootstrap.sh` — creates the Terraform backend (S3 + DynamoDB),
   configures the `infra` stack to use it, and shows you the plan.
3. `cd terraform/infra && terraform apply` — provisions VPC, EKS
   (`vantra-shared-eks`), IRSA role, ECR repo, S3 bucket, DynamoDB table, and
   installs the AWS Load Balancer Controller. Takes ~15-20 minutes for EKS.
4. Note the `terraform output` values and set them as GitHub Actions repo
   secrets:
   - `AWS_DEPLOY_ROLE_ARN` ← `terraform output -raw github_actions_deploy_role_arn`
     (this stack creates the GitHub OIDC provider and a role scoped to this
     repo — no static AWS keys needed in GitHub)
   - `METER_READING_IRSA_ROLE_ARN` ← `terraform output -raw meter_reading_service_role_arn`
   - `METER_BUCKET_NAME` ← `terraform output -raw meter_bucket_name`
   - `METER_TABLE_NAME` ← `terraform output -raw meter_table_name`

   If your repo path isn't `naveen352/Real-Scenarios`, set
   `-var="github_repo=<owner>/<repo>"` on `terraform apply` (or edit the
   default in `github-oidc.tf`) so the trust policy matches.
5. Push to `main` (or re-run the workflow) to build, push, and deploy via
   GitHub Actions.
6. `aws eks update-kubeconfig --region ap-south-1 --name vantra-shared-eks` to
   point `kubectl` at the cluster locally.

## 🔍 Investigate

Work the incident. Some starting points you might reach for (not a checklist —
use what's relevant):

- `kubectl get pods,svc,endpoints,ingress -n vantra-billing`
- `kubectl describe pod <pod> -n vantra-billing`
- `kubectl logs <pod> -n vantra-billing`
- `kubectl describe svc meter-reading-service-meter-reading-service -n vantra-billing`
- `kubectl get endpoints -n vantra-billing`
- `helm get values meter-reading-service -n vantra-billing`
- `helm template ./helm/meter-reading-service -f ./helm/meter-reading-service/values.yaml`
- ALB target group health in the AWS Console or via `aws elbv2 describe-target-health`
- `aws ecr list-images --repository-name vantra-meter-reading/meter-reading-service`
- `aws iam get-role --role-name vantra-meter-reading-meter-reading-service-irsa` /
  `aws iam get-role-policy` / trust policy inspection
- GitHub Actions run logs for the deploy workflow

Document what you find below as you go. Tell me what you checked and what you
saw before I confirm or redirect.

_(your investigation notes go here)_

## ✅ Solution

_(fill in once root cause(s) are confirmed)_

## 📎 Notes

_(anything worth remembering for next time goes here)_
