# MyApplication - Daily Journal

A small Java/Spring Boot app deployed on Tomcat, backed by PostgreSQL, served
through an ALB on EKS.

**Flow:** the homepage banner asks *"Have you already been to this
application?"*. New users fill in Name / Age / DOB / PAN number, then are
taken straight to "write about today". Returning users just enter their PAN
number; if it matches an existing record they land on a dashboard with
**Add a new post** and **View my previous posts**.

PAN numbers are sensitive PII: the app never stores the plaintext value.
It stores a keyed HMAC-SHA256 hash (used to look returning users up) and a
masked copy (`XXXXX1234F`, for display only) - see
[`PanUtil.java`](app/src/main/java/com/myapp/dailyjournal/util/PanUtil.java).
Note this design authenticates a returning user by PAN alone, which is
identification, not real authentication (a PAN isn't a secret) - fine for
this exercise, not something to reuse as-is for a system holding real PII.

## Layout

```
app/        Spring Boot source (WAR packaging, deployed onto Tomcat 10.1)
docker/     Dockerfile (app, multi-stage: maven build -> tomcat runtime),
            docker-compose.yml (app + stock postgres:16-alpine, no k8s needed)
k8s/        Namespaces, Postgres StatefulSet, app Deployment, Ingress, NetworkPolicies
scripts/    build-and-push.sh - builds the image and pushes it to ECR
```

The cluster, ECR repo, and everything IAM/IRSA-related for the ingress
controller are provisioned separately in
[`../Infra_For_MyApplication`](../Infra_For_MyApplication) (Terraform).

## Stack

- Java 17, Spring Boot 3 (WAR), Thymeleaf views, Spring Data JPA
- Tomcat 10.1 (external, via Docker - not the embedded server)
- PostgreSQL 16, one StatefulSet + PVC in its own namespace
- AWS ALB via `k8s/ingress.yaml` (needs the AWS Load Balancer Controller,
  installed by the Terraform in `Infra_For_MyApplication`)
- `myapp` namespace for the app, `myapp-db` namespace for Postgres, both
  locked down with NetworkPolicies (app only reachable from the VPC/ALB on
  8080; Postgres only reachable from the app's pods on 5432)

## Deploy order

1. **Provision the cluster + ECR + ALB controller** - see
   `../Infra_For_MyApplication/README.md` (`terraform apply`), then:
   ```bash
   aws eks update-kubeconfig --region ap-south-1 --name myapp-eks
   ```

2. **Create the namespaces**
   ```bash
   kubectl apply -f k8s/namespaces.yaml
   ```

3. **Create real secrets** (don't apply the placeholder files as-is in a
   shared/real environment - see the comments inside `k8s/db/secret.yaml`
   and `k8s/app/secret.yaml` for the imperative `kubectl create secret`
   equivalents). Both secrets must use the **same** Postgres password.

4. **Deploy Postgres**
   ```bash
   kubectl apply -f k8s/db/storageclass.yaml
   kubectl apply -f k8s/db/serviceaccount.yaml
   kubectl apply -f k8s/db/secret.yaml        # or your kubectl create secret command
   kubectl apply -f k8s/db/statefulset.yaml
   kubectl apply -f k8s/db/service.yaml
   kubectl -n myapp-db rollout status statefulset/postgres
   ```

5. **Build and push the image**
   ```bash
   ./scripts/build-and-push.sh v1
   ```
   Then edit `k8s/app/deployment.yaml`, replacing `REPLACE_WITH_ECR_REPOSITORY_URL:latest`
   with the ECR URL the script (or `terraform output ecr_repository_url`) printed.

6. **Deploy the app + Ingress**
   ```bash
   kubectl apply -f k8s/app/serviceaccount.yaml
   kubectl apply -f k8s/app/secret.yaml       # or your kubectl create secret command
   kubectl apply -f k8s/app/configmap.yaml
   kubectl apply -f k8s/app/deployment.yaml
   kubectl apply -f k8s/app/service.yaml
   kubectl apply -f k8s/ingress.yaml
   ```

7. **Lock down networking**
   ```bash
   kubectl apply -f k8s/networkpolicy/
   ```

8. **Get the URL**
   ```bash
   kubectl -n myapp get ingress daily-journal
   # ADDRESS column = the ALB's DNS name, once it finishes provisioning (~2-3 min)
   ```

Steps 2-7 can also be done in one shot with `kubectl apply -k k8s/` once the
placeholder secrets/image have been edited to real values (already verified
to build correctly with `kubectl kustomize k8s/`).

## Local development

**Option A - Docker only (recommended before touching k8s at all):**
```bash
cd docker
cp .env.example .env   # edit POSTGRES_PASSWORD / APP_PAN_SECRET
docker compose up --build
```
Credentials live in `docker/.env` (gitignored), not in `docker-compose.yml`
itself - compose will refuse to start if `POSTGRES_PASSWORD` or
`APP_PAN_SECRET` aren't set. This builds the app image, pulls stock
`postgres:16-alpine` for the database, wires them together on a compose
network, and serves the app at `http://localhost:8080`. `docker compose
down -v` tears it down and drops the data volume.

**Option B - run the app on your host, Postgres in Docker:**
```bash
docker run -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres:16-alpine
cd app
mvn spring-boot:run
```
`application.yml` defaults `SPRING_DATASOURCE_*` to `localhost:5432` /
`postgres` / `postgres` and `APP_PAN_SECRET` to a dev placeholder, so no env
vars are required for this path either - just override them in your
Kubernetes Secrets for anything real.

## Notes / things to harden before this is a real production app

- `spring.jpa.hibernate.ddl-auto: update` is used for simplicity; swap for
  Flyway/Liquibase migrations for anything long-lived.
- The Secret manifests in `k8s/` contain placeholder values as documentation
  of what keys are expected - replace them via `kubectl create secret`
  rather than editing+applying the YAML, and never commit real secrets.
- PAN-as-login is identification, not authentication; add a real auth layer
  (OTP/password/SSO) if this ever handles real user data.
