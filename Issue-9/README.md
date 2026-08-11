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

Separately, engineers have confirmed the Jenkins pipeline itself now correctly
fails a build if the deploy command doesn't actually succeed on the host — so
whatever's happening here, it's not the pipeline lying about success.

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

---

## ✅ Solution

### Issue 1 — deploy command fails, `no basic auth credentials`

**Symptom:** the pipeline's Deploy stage now properly fails (it checks the SSM
command's actual result, not just whether it was submitted). Console output
shows something like:

```
pull access denied, repository does not exist or may require authorization:
authorization failed: no basic auth credentials
```

**Root cause:** `terraform/iam.tf` — `app_instance_role` (the app host's
instance role) only has `AmazonSSMManagedInstanceCore` attached. Jenkins can
push to ECR because *it* runs under a completely separate role
(`vantra-jenkins-controller-role`) with ECR push permissions — but nobody
ever gave the **app host** permission to pull.

**Fix — add to `terraform/iam.tf`:**
```hcl
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.app_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
```
Then `terraform apply`. No instance replacement needed — EC2 refreshes role
credentials via IMDS automatically within a few minutes.

---

### Issue 2 — `/healthz` is fine, but `POST /api/v1/invoices` returns 500

**Symptom:** deploy succeeds, container is `Up` and healthy, but generating
an invoice fails:
```
PermissionError: [Errno 13] Permission denied: '/data/invoices/...'
```

**Root cause — two layers:**

1. `Dockerfile`: `USER appuser` runs before `/data/invoices` is created and
   owned, so the image itself has a permission mismatch baked in.
2. Even after fixing the image, `scripts/deploy_via_ssm.sh` bind-mounts the
   **host's** `/data/invoices` over the container's (`-v /data/invoices:/data/invoices`).
   Docker auto-created that host directory as `root` the first time this ran
   (before it existed), and a bind mount always wins over whatever the image
   itself contains — so an image-level fix alone never takes effect at runtime.

**Fix — Dockerfile, correct order + create+chown as root before switching user:**
```dockerfile
RUN mkdir -p /data/invoices && chown -R appuser:appgroup /data/invoices
USER appuser
```

**Then pick one for the host-side ownership mismatch:**

- **Option 1 (quick, fragile):** find the UID `appuser` actually got assigned
  and `chown` the host directory to match:
  ```bash
  sudo docker exec <container> id appuser        # e.g. uid=999
  sudo chown -R 999:999 /data/invoices
  sudo docker restart <container>
  ```
  Downside: `useradd -r` assigns an arbitrary system UID. A future image
  rebuild can silently shift it, and you're back to this exact bug with no
  code change to explain why.

- **Option 2 (durable):** pin a fixed UID/GID in the Dockerfile so it never
  drifts across rebuilds:
  ```dockerfile
  RUN groupadd -r -g 888 appgroup && useradd -r -u 888 -g appgroup appuser
  RUN mkdir -p /data/invoices && chown -R appuser:appgroup /data/invoices
  USER appuser
  ```
  `chown -R 888:888 /data/invoices` on the host once — it stays correct
  across every future rebuild/restart, since the UID is now fixed by the
  Dockerfile itself instead of auto-assigned by `useradd`.
