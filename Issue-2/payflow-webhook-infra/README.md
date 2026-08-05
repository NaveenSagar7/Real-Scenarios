# payflow-webhook-infra

Terraform stack for the `webhook-processor` service — VPC, ALB, ASG, IAM instance profile.

## Deploy

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Ticket: PAYFLOW-2298

`terraform apply` completes cleanly (14 resources added, 0 errors), but:
1. ALB DNS name times out when accessed.
2. EC2 instances cannot write to the S3 bucket via their IAM instance profile.

Investigate and fix both using Terraform only — no manual console/CLI patches.
Ticket isn't closed until `terraform plan` shows no drift after the fix.


# PAYFLOW-2298 — Root Cause & Fix

## Issue 1: ALB URL times out (no response)

**Root cause:** The Auto Scaling Group's launch template `user_data` never actually starts the `webhook-processor` application — it only writes a log line. No process binds to port 8080 on the instances, so the ALB's health checks fail and the target group has zero healthy targets. With no healthy backend, requests to the ALB hang/time out instead of returning a clean response.

A secondary misconfiguration compounds it: the target group's health check path is set to `/health`, but the application's actual health endpoint is `/healthz`.

**Fix:**
- `asg.tf` — update `user_data` so it installs/starts the actual application (or, until a real deploy pipeline exists, a process that binds to port 8080 and responds `200` on `/healthz`).
- `alb.tf` — correct the target group health check path from `/health` to `/healthz`.
- Apply via Terraform, then trigger an ASG instance refresh so existing instances relaunch with the corrected launch template (an EC2 launch template change doesn't retroactively update instances already running).

---

## Issue 2: EC2 instances can't write to S3 despite an attached IAM role

**Root cause:** The IAM role's trust policy (`assume_role_policy`) had the wrong principal — it trusted `s3.amazonaws.com` instead of `ec2.amazonaws.com`. A role's trust policy controls *who is allowed to assume the role*, separate from its permissions policy (*what the role can do*). Since EC2 was never a trusted principal, the instances could never actually assume the role in the first place — making the correctly-scoped S3 `PutObject`/`GetObject` permissions irrelevant, since the role was never usable to begin with.

**Fix:**
- `iam.tf` — change the trust policy's `Principal.Service` from `s3.amazonaws.com` to `ec2.amazonaws.com`.
- Apply via Terraform. Existing instances need to re-assume the role (an ASG instance refresh is the reliable way to force this, since role assumption happens at instance boot/credential-refresh time).
- Also confirm the target S3 bucket (`payflow-webhook-logs`) actually exists — it is not provisioned anywhere in this Terraform stack, so even with the trust policy fixed, writes will fail with `NoSuchBucket` if the bucket itself was never created out-of-band.