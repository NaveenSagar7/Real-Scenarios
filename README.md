# Lab #009 — Ticket Assigned

**Ticket ID:** VANTRA-4315
**Priority:** P2
**Component:** Jenkins CI/CD — `billing-invoice-service` (Docker build → ECR → EC2)
**Reported by:** Billing Ops team, after customers reported broken invoice downloads

## 1. Background

**Company:** Vantra — regional utility billing provider, `ap-south-1`.

**Existing infrastructure:** `billing-invoice-service` is a new microservice
(Python/Flask) that generates a PDF invoice on request and lets billing ops fetch
it back. It's containerized, built and pushed to a private ECR repo, and deployed
to a single EC2 host running Docker — no Kubernetes, no ASG, just Jenkins pushing
the container to a known instance over SSM Run Command (there's no SSH access to
this host, same as the rest of Vantra's fleet).

**What changed:** The service went through its first full pipeline run yesterday —
image built, pushed to ECR, and "deployed." Jenkins reported the whole pipeline as
`SUCCESS`.

**Why this ticket exists:** Billing ops started filing tickets this morning —
customers hitting "download invoice" get failures. Support checked and the app's
`/healthz` endpoint responds fine. The problem only shows up when someone actually
tries to generate an invoice.

Separately, the on-call engineer noticed the container currently running on the
host is **not** running the image from yesterday's build — it looks like whatever
was running before is still there, untouched. Nobody's sure if yesterday's deploy
even reached the host.

## 2. Objective

Get `billing-invoice-service` actually generating and serving invoices on the EC2
host — running the image that Jenkins built, not a stale one. Confirm it
end-to-end (a real `POST /api/v1/invoices` succeeds and the PDF is fetchable), not
just "the pipeline shows green" or "`/healthz` returns 200."

I'm not telling you what's wrong or how many issues there are. Investigate using
Jenkins console output, `docker logs`/`docker exec` on the host (via SSM), IAM
policy inspection, and SSM command history.

## 3. Repository Structure

```
vantra-billing-invoice-service/
├── app/
│   ├── app.py
│   └── requirements.txt
├── Dockerfile
├── bootstrap/
│   └── main.tf                # shared VPC + TF remote state (skip if already applied)
├── terraform/
│   ├── backend.tf, network.tf, variables.tf
│   ├── ecr.tf, iam.tf, ec2.tf
│   ├── jenkins_host.tf, jenkins_iam.tf   # Jenkins controller - fully bootstrapped
├── Jenkinsfile
├── scripts/
│   ├── deploy_via_ssm.sh
│   └── smoke_test.sh
└── README.md
```

## Setup (in order)

```bash
# Skip if you already applied it for an earlier Vantra lab
cd bootstrap && terraform init && terraform apply

cd ../terraform
terraform init
```

Before applying, set `corp_cidr` to **your own IPv4** (the default is a
placeholder and won't let you reach anything):

```bash
terraform apply -var="corp_cidr=$(curl -4 -s ifconfig.me)/32"
```

This creates: the ECR repo, the app host (Docker, no app deployed yet), and
the **Jenkins controller** — Java, Docker, git, AWS CLI v2, Terraform, and
Jenkins itself all installed via `user_data`, with an IAM role already
scoped for exactly what the pipeline needs (ECR push, SSM send-command,
Terraform-state read). Nothing left to install by hand.

## Get into Jenkins

```bash
terraform output -raw jenkins_public_ip
terraform output -raw jenkins_instance_id
```

Open `http://<jenkins_public_ip>:8080`. Grab the initial admin password
(no SSH — go through SSM):

```bash
aws ssm start-session --target "$(terraform output -raw jenkins_instance_id)"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Install suggested plugins, create your admin user.

## Configure the pipeline job

1. Push this repo to your GitHub (`naveen352/Real-Scenarios`, or wherever
   you're keeping these labs) — Jenkins needs a URL to pull from.
2. In Jenkins: **New Item → Pipeline** → name it `billing-invoice-service`
3. Under **Pipeline**, set Definition to **"Pipeline script from SCM"**,
   SCM: Git, Repository URL: your repo, script path: `Jenkinsfile`
4. If the repo is private, add credentials under **Manage Jenkins →
   Credentials** (a GitHub PAT works) and select them in the job config.
   If it's public, skip this — no credentials needed.
5. **Build Now**

**Access to the app host during investigation:** SSM-only, no SSH/bastion.
```bash
aws ssm start-session --target <app-host-instance-id>
aws ssm list-command-invocations --instance-id <id> --details
```

Trigger the pipeline, then bring me the Jenkins console output for each stage —
paste what you actually see, not a summary.
