# PAYFLOW-2298 — webhook-processor Terraform/AWS

**Priority:** P1
**Component:** Terraform / AWS (VPC, ALB, ASG, IAM)
**Status:** Resolved

---

## 🎫 The Ticket

**Company:** PayFlow — fintech company processing merchant payment webhooks.

**Service:** `webhook-processor` — a service that receives async payment-status callbacks from card networks and writes them to a queue for downstream settlement processing. Runs on EC2 in an Auto Scaling Group behind an ALB, in a standard 2-tier VPC (public ALB, private ASG subnets). Needs to write logs to an S3 bucket (`payflow-webhook-logs`) via an IAM instance profile — no static credentials, ever.

**What changed:** Platform team stood up this environment fresh in a **new AWS account** (account isolation per compliance requirement). An engineer replicated the existing `prod` Terraform into the new account and ran `terraform apply` — it completed with **no errors**: `Apply complete! Resources: 14 added, 0 changed, 0 destroyed.`

**What happened:** Despite the clean apply, QA got connection timeouts hitting the ALB DNS name. Separately, EC2 instance logs showed the app couldn't write to S3 at all — two symptoms, unclear if related.

**Objective:** Get the ALB routing traffic to healthy instances, **and** get instances writing to S3 via their IAM instance profile — Terraform only, no manual console/CLI patches. Not closed until `terraform plan` shows no drift after the fix.

---

## 🚀 Deploy the Infra

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Requires a pre-existing S3 bucket + DynamoDB table for the Terraform backend (state storage/locking) — provisioned once, out-of-band, not part of this stack.

---

## 🔍 Commands to Start Investigating

```bash
# Is the ALB actually reachable?
curl -v http://<alb-dns-name>

# What does the ALB think of its own targets?
aws elbv2 describe-target-health --target-group-arn <tg-arn>

# Are the instances actually running?
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names <asg-name>

# Can the instance role even be assumed? (trust policy, not permissions)
aws iam get-role --role-name <role-name> --query 'Role.AssumeRolePolicyDocument'

# Does the target S3 bucket even exist?
aws s3api head-bucket --bucket payflow-webhook-logs
```

---

## ✅ Solution

**Issue 1 — ALB times out (zero healthy targets)**
The ASG launch template's `user_data` never actually started the app — it only wrote a log line. Nothing bound to port 8080, so every health check failed. Secondary issue: the target group's health check path was `/health`, but the app's real endpoint is `/healthz`.

Fix:
- `asg.tf` — update `user_data` to actually start a process on port 8080.
- `alb.tf` — correct the health check path to `/healthz`.
- Apply, then trigger an **ASG instance refresh** — a launch template change doesn't retroactively update instances already running.

**Issue 2 — EC2 can't write to S3 despite an attached IAM role**
The role's trust policy trusted the wrong principal — `s3.amazonaws.com` instead of `ec2.amazonaws.com`. A trust policy controls *who can assume the role*; this is separate from the permissions policy (*what the role can do*). Since EC2 was never a trusted principal, the correctly-scoped S3 permissions were irrelevant — the role could never be assumed in the first place.

Fix:
- `iam.tf` — change `Principal.Service` from `s3.amazonaws.com` to `ec2.amazonaws.com`.
- Apply, then trigger an **ASG instance refresh** — role assumption happens at instance boot, so existing instances won't pick up the fix on their own.

```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name <asg-name> \
  --preferences '{"MinHealthyPercentage": 0, "InstanceWarmup": 60}'
```

---

## 📎 Additional Notes

**Also confirm the S3 bucket actually exists.** `payflow-webhook-logs` is never provisioned anywhere in this Terraform stack — even with the trust policy fixed, writes will fail with `NoSuchBucket` if the bucket was never created out-of-band.

**Why `terraform apply` succeeding didn't mean anything was actually working:** a clean apply only proves the resources are schema-valid and got created — it says nothing about whether they're functionally wired together correctly (trust relationships, health check correctness, whether a process is actually running inside an instance). Both root causes here were logical/runtime problems invisible to Terraform's own validation.