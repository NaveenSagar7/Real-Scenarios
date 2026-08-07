# Ticket: FINEDGE-2201

**Reporter:** Platform Engineering
**Component:** transaction-audit
**Priority:** P1
**Environment:** Production (ap-south-1)

## Background

FinEdge is a digital banking platform. `transaction-audit` is a small
service that every completed transaction gets routed through — it writes an
immutable audit record to S3 for compliance retention. Regulatory
requirements mean gaps in this trail get escalated straight to
engineering leadership, so this component is treated as tier-1.

The service has always run as a single EC2 instance with an instance
profile attached — simple, but a known single point of failure that's come
up in every infra review for the last two quarters. This sprint, Platform
Engineering moved it onto the company's new shared EKS cluster, deployed via
Helm, using IRSA (IAM Roles for Service Accounts) instead of an instance
profile, with an ALB Ingress in front for the internal callers that hit it
over HTTP.

QA signed off in staging. In production, the pods come up and pass their
Kubernetes readiness probes, but audit records are not landing in S3, and
the internal callers hitting the ALB are getting inconsistent 502s. Given
the compliance angle, this got escalated same-day instead of waiting for
next sprint.

## Objective

Get `transaction-audit` running on EKS such that: pods can actually write
to the S3 audit bucket using their IRSA role (not a fallback path), and the
ALB Ingress reliably routes traffic to healthy pods.

No further detail will be provided. Investigate as delivered, form a
hypothesis, and tell me what you find before changing anything.

## Repository Structure

```
Issue-008/
├── README.md
├── app/
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── terraform/
│   ├── bootstrap/
│   │   └── main.tf          # run first (local state) - S3 + DynamoDB backend
│   ├── backend.tf
│   ├── variables.tf
│   ├── vpc.tf
│   ├── eks.tf                # cluster, node group, OIDC provider
│   ├── iam-irsa.tf            # S3 bucket + IRSA role for the service account
│   └── outputs.tf
└── helm/
    └── transaction-audit/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── serviceaccount.yaml
            ├── deployment.yaml
            ├── service.yaml
            └── ingress.yaml
```

## Getting It Running

1. `cd terraform/bootstrap && terraform init && terraform apply` — creates
   the remote state bucket + DynamoDB lock table.

Pre-req : mkdir -p terraform/.helm-cache
2. `cd ../` and run:
   ```
   terraform init \
     -backend-config="bucket=<state_bucket_name>" \
     -backend-config="region=ap-south-1" \
     -backend-config="dynamodb_table=finedge-eks-terraform-locks"
   terraform apply -var="audit_bucket_name=<a globally-unique bucket name>"
   ```
3. `aws eks update-kubeconfig --region ap-south-1 --name finedge-eks`

   `terraform apply` in step 2 already provisioned the cluster, the node
   group, and installed the AWS Load Balancer Controller into `kube-system`
   (its own IRSA role included) — nothing to install by hand.
4. Update `helm/transaction-audit/values.yaml` with the `irsa_role_arn` and
   `audit_bucket` values from the Terraform outputs.
5. `helm install transaction-audit helm/transaction-audit -n fintech --create-namespace`

## Ground Rules

- I'm not going to tell you which file has the problem.
- Tell me what you observed and what you've ruled out before I give any hints.
- Assume there's more than one thing wrong.

# FINEDGE-2201 — Resolution

## Issue 1: Pods never scheduled

**Finding:** `kubectl describe deployment` showed `0/2 replicas created`. Events on
the ReplicaSet:
```
Error creating: pods "transaction-audit-..." is forbidden: error looking up
service account fintech/transaction-audit-sa: serviceaccount "transaction-audit-sa" not found
```

**Root cause:** `helm/transaction-audit/templates/deployment.yaml` hardcoded
`serviceAccountName: transaction-audit-sa`. The actual ServiceAccount object
created by the chart is named `transaction-audit` (from `values.yaml`). The
mismatch caused the Kubernetes ServiceAccount admission controller to reject
pod creation outright.

**Fix:** Changed `serviceAccountName` in `deployment.yaml` to reference
`transaction-audit` (matching `serviceaccount.yaml`).

---

## Issue 2: ALB target group failed to provision

**Finding:** Ingress events:
```
Failed deploy model due to InvalidParameter: 1 validation error(s) found.
- minimum field value of 1, CreateTargetGroupInput.Port.
```

**Root cause:** `service.yaml` used `type: ClusterIP`, and the Ingress had no
`target-type` annotation, so the AWS Load Balancer Controller defaulted to
`instance` mode — which requires a NodePort. `ClusterIP` services don't get
one, so the controller tried to register target group port `0`.

**Fix:** Added `alb.ingress.kubernetes.io/target-type: ip` to the Ingress
annotations in `values.yaml`, keeping `service.type: ClusterIP`. The
controller now registers pod IPs directly instead of relying on NodePorts.

---

## Issue 3: Pods healthy, ALB routing, but S3 writes failed

**Finding:** `/audit/write` returned:
```json
{"error": "An error occurred (AccessDenied) when calling the
AssumeRoleWithWebIdentity operation: Not authorized to perform
sts:AssumeRoleWithWebIdentity"}
```

**Root cause:** `terraform/iam-irsa.tf` hardcoded the IAM trust policy's
`sub` condition to `system:serviceaccount:fintech:audit-writer`, but the
actual ServiceAccount is `transaction-audit`. The JWT presented by the pod
didn't match what the trust policy expected, so STS denied the assume-role
call before ever evaluating the role's permissions.

**Fix:** Changed the trust policy condition in `iam-irsa.tf` to use
`var.service_account_name` instead of the hardcoded `audit-writer` string.

---

## Verification

```
curl -H "Host: transaction-audit.finedge.internal" http://<alb-dns>/audit/write
```
```json
{"bucket":"transaction-bucket-naveen-issue-eight","written":"audit-records/....json"}
```
Confirmed in S3 via `aws s3 ls s3://transaction-bucket-naveen-issue-eight/audit-records/`.

FYI : Use helm upgrade to re-deploy during issues.

# FINEDGE-2201 — Infra Teardown

Order matters. The AWS Load Balancer Controller creates the ALB outside
Terraform's state — it must be removed first while the controller is still
running to hear the delete event, or you're left with an orphaned ALB.

## 1. Uninstall the app (releases the ALB)

```bash
helm uninstall transaction-audit -n fintech
```

Confirm the ALB is actually gone before continuing — poll until empty:
```bash
aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-fintech')]"
```

## 2. Empty the S3 audit bucket

Terraform won't delete a non-empty bucket:
```bash
aws s3 rm s3://transaction-bucket-naveen-issue-eight --recursive
```

## 3. Destroy the main stack

```bash
cd terraform
terraform destroy -var="audit_bucket_name=transaction-bucket-naveen-issue-eight"
```

Tears down: EKS cluster, node group, OIDC provider, VPC/subnets/IGW/route
tables, all IAM roles/policies, the S3 bucket, and the ALB controller's
Helm release. EKS cluster deletion is the slow part (~8-12 min).

## 4. Destroy the bootstrap (state backend) stack

```bash
cd bootstrap
terraform destroy -var="state_bucket_name=<your bootstrap bucket name>"
```

If the S3 bucket has versioning enabled and refuses to delete
(`BucketNotEmpty`), purge all versions first:
```bash
aws s3api delete-objects --bucket <bucket-name> \
  --delete "$(aws s3api list-object-versions --bucket <bucket-name> \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)"

aws s3api list-object-versions --bucket <bucket-name>
# confirm empty, then re-run terraform destroy
```

If `aws_s3_bucket.tf_state` still has `lifecycle { prevent_destroy = true }`,
remove that block, `terraform apply` once, then `terraform destroy` again.

## 5. Verify nothing's left billing

```bash
aws eks list-clusters
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=finedge-transaction-audit-vpc"
aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-fintech')]"
aws ec2 describe-instances --filters "Name=tag:eks:cluster-name,Values=finedge-eks" "Name=instance-state-name,Values=running"
aws s3api list-buckets --query "Buckets[?contains(Name, 'finedge') || contains(Name, 'transaction')].Name"
```

All should return empty (except possibly the state bucket, if you kept it).