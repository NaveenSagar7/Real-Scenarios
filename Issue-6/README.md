# settlement-batch-processor — Jenkins Pipeline

## Prerequisites (one-time Jenkins setup — this part is unavoidable UI work, not the ticket itself)

Jenkins itself has to be stood up and configured through its UI the first time — there's no way around that part being manual, so here it is in full, step by step, so you're not guessing mid-debug.

### 1. Start Jenkins

```bash
docker-compose up -d
```

### 2. Get the initial admin password

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 3. Open Jenkins and finish setup

- Go to `http://localhost:8080`
- Paste the password from step 2
- Click **"Install suggested plugins"** and wait for it to finish
- Create your admin user when prompted

### 4. Install one additional plugin (not in the "suggested" set)

- **Manage Jenkins → Plugins → Available plugins**
- Search for **"Docker Pipeline"** → check it → **Install without restart**

### 5. Add your Docker Hub credentials

- **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**
- Kind: **Username with password**
- Username / Password: your Docker Hub username and an access token (same kind you generated in Lab #003 — regenerate a **Read & Write** scoped token if you no longer have one)
- **ID**: `dockerhub-creds` — set this exact ID, it matters
- Click **Create**

### 6. Create the pipeline job

- **New Item → name it `settlement-batch-pipeline` → select "Pipeline" → OK**
- Scroll to the **Pipeline** section
- Definition: **Pipeline script**
- Paste the entire contents of this repo's `Jenkinsfile` into the script box
- **Save**

### 7. Trigger it

- Click **Build Now**

That's the full one-time setup — nothing else needs configuring before the ticket starts.

---

## Ticket: PAYFLOW-5019

First build never completes — no clear pass or fail. A retry eventually errors out further along. Investigate using the build's **Console Output**. No manual workarounds — the pipeline itself needs to be fixed so `Build Now` reliably succeeds end to end.


# PAYFLOW-5019 — Root Cause & Fix

## Issue 1: Pipeline never started — stuck waiting

**Cause:** `Jenkinsfile` used `agent { label 'docker' }`, but no agent/node in this Jenkins instance was labeled `docker`. Jenkins just sat waiting indefinitely for an executor that didn't exist.

**Fix:** Changed to `agent any`, so it runs on the built-in node — which has Docker CLI available via the mounted `docker.sock`.

---

## Issue 2: Pipeline failed at the Push stage

**Error:**
```
ERROR: Could not find credentials entry with ID 'dockerhub-cred'
```

**Cause:** `Jenkinsfile` referenced `credentialsId: 'dockerhub-cred'`, but the credential actually stored in Jenkins was saved with ID `dockerhub-creds`. Jenkins credential lookups are exact-match — the missing `s` meant no match was found.

**Fix:** Corrected the reference to `credentialsId: 'dockerhub-creds'`.

---

## Result

Pipeline ran end to end: Build → Test → Push, `Finished: SUCCESS`. Image confirmed pushed and pullable — `naveen352/settlement-batch-processor:latest`.