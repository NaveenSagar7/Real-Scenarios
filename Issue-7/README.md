# Ticket: STREAMLY-1123

**Reporter:** Site Reliability (on-call)
**Component:** catalog-api
**Priority:** P2
**Environment:** Production (ap-south-1)

## Background

PulseStream is a mid-size OTT streaming platform. The `catalog-api` service
serves title metadata to the mobile and smart-TV clients — it's a
low-complexity but high-traffic read path sitting behind the main ALB.

Until last sprint, `catalog-api` ran on a legacy EC2 Auto Scaling group with
manual deploys. The platform team migrated it to ECS Fargate, fronted by the
existing ALB, with releases going through CodePipeline → CodeBuild → CodeDeploy
(ECS blue/green). This is meant to be a standard, low-risk lift-and-shift —
same app code, new deployment path.

Since the migration went live, on-call has been paged twice: once for a
pipeline deployment that never completed, and once for the ALB target group
alarming on unhealthy hosts even though ECS shows the service as steady state
with the desired count of tasks running. Engineering has not yet root-caused
either page. This ticket was opened to get the service stable before the
next release freeze.

## Objective

Get `catalog-api` deploying cleanly through the pipeline, with the ECS
service reporting healthy, traffic-serving targets behind the ALB.

No further detail will be provided. Investigate the infrastructure as
delivered, form a hypothesis, and tell me what you find before you start
changing files.

## Repository Structure

```
Issue-007/
├── README.md
├── app/
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── buildspec.yml
├── appspec.yaml
├── taskdef.json
└── terraform/
    ├── bootstrap/
    │   └── main.tf          # run this first (local state) - creates the S3 + DynamoDB backend
    ├── backend.tf
    ├── provider config is inside backend.tf
    ├── variables.tf
    ├── vpc.tf
    ├── alb.tf
    ├── ecs.tf
    ├── iam.tf
    ├── codebuild.tf
    ├── codedeploy.tf
    ├── codepipeline.tf
    └── outputs.tf
```

## Getting It Running

1. `cd terraform/bootstrap && terraform init && terraform apply` — creates the
   remote state bucket + DynamoDB lock table. Note the outputs.
2. `cd ../` (back in `terraform/`) and run:
   ```
   terraform init \
     -backend-config="bucket=<state_bucket_name>" \
     -backend-config="region=ap-south-1" \
     -backend-config="dynamodb_table=streamly-terraform-locks"
   terraform apply
   ```
3. In the AWS Console, approve the pending CodeStar GitHub connection
   (Developer Tools → Settings → Connections) — this is the one manual step,
   OAuth handshakes can't be scripted.
4. Push this folder to the `naveen352/Real-Scenarios` repo on `main` to
   trigger the pipeline, or manually start it from the CodePipeline console.

Everything else — VPC, ALB, target groups, ECS cluster/service, ECR, IAM
roles, CodeBuild project, CodeDeploy app/deployment group, CodePipeline — is
provisioned for you.

## Ground Rules

- I'm not going to tell you which file has the problem.
- Tell me what you observed and what you ruled out before I give any hints.
- Assume there's more than one thing wrong.
