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
