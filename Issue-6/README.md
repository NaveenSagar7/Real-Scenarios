# PAYFLOW-5019 — settlement-batch-processor Jenkins Pipeline

**Priority:** P2
**Component:** Jenkins — `settlement-batch-processor` pipeline
**Status:** Resolved

---

## 🎫 The Ticket

**Company:** PayFlow (same org as PAYFLOW-2298, PAYFLOW-3107, PAYFLOW-4402).

**Service:** `settlement-batch-processor` — a small containerized batch job. Piloting **Jenkins** for this service instead of GitHub Actions, since some legacy on-prem-adjacent services need Jenkins for compliance/audit-trail reasons specific to settlement processing.

**What changed:** A release engineer stood up a fresh Jenkins instance and wrote a Declarative Pipeline (`Jenkinsfile`) to build, test, and push the image to Docker Hub — mirroring the GitHub Actions workflow from PAYFLOW-3107, just in Jenkins syntax.

**What happened:** First pipeline run was triggered via "Build Now." It never completed — no clear pass or fail, it just sat there. A second attempt (after waiting) eventually errored out further along.

**Objective:** Get the pipeline to run to completion — build, test, and push the image to Docker Hub — end to end, no manual workarounds.

---

## 🚀 Deploy / Setup

Jenkins itself has to be stood up through its UI once — unavoidable manual work, not part of the ticket itself.

```bash
docker-compose up -d
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```
- Open `http://localhost:8080`, paste the password, install suggested plugins, create admin user.
- **Manage Jenkins → Plugins → Available** → install **"Docker Pipeline"**.
- **Manage Jenkins → Credentials → Global** → add a Username/Password credential for Docker Hub, **ID: `dockerhub-creds`**.
- **New Item** → Pipeline → paste the `Jenkinsfile` contents as a **Pipeline script** → Save.
- Click **Build Now**.

---

## 🔍 Commands to Start Investigating

- Open the build → **Console Output** (classic view or Blue Ocean).
- If a build just sits with no progress, check what it's actually waiting on before assuming it's hung randomly.

---

## ✅ Solution

**Issue 1 — Pipeline never started, stuck waiting.**
`Jenkinsfile` used `agent { label 'docker' }`, but no agent/node in this Jenkins instance was labeled `docker` — Jenkins sat waiting indefinitely for an executor that didn't exist.

Fix: changed to `agent any`, so it runs on the built-in node (which has Docker CLI available via the mounted `docker.sock`).

**Issue 2 — Pipeline failed at the Push stage.**
```
ERROR: Could not find credentials entry with ID 'dockerhub-cred'
```
`Jenkinsfile` referenced `credentialsId: 'dockerhub-cred'`, but the stored credential's actual ID was `dockerhub-creds` — Jenkins credential lookups are exact-match, and the missing `s` meant no match.

Fix: corrected the reference to `credentialsId: 'dockerhub-creds'`.

**Result:** Pipeline ran end to end — Build → Test → Push, `Finished: SUCCESS`. Image confirmed pushed and pullable: `naveen352/settlement-batch-processor:latest`.

---

## 📎 Additional Notes

Same root-cause *category* as PAYFLOW-3107 (GitHub Actions secret name typo) — an exact-match identifier (credential ID / secret name) that has to stay in sync across two separate places (the credential store and the pipeline script), with nothing enforcing that it does. Worth treating any hardcoded ID reference like this as a spot to double-check, regardless of which CI tool is in use.