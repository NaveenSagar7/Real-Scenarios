# notification-service

Flask microservice — sends transaction notifications to merchants. Built and pushed to Docker Hub via GitHub Actions on every push to `main`.

## Prerequisites (do these once, before triggering the workflow)

1. **Create a new GitHub repository** (public or private, your choice) and push this entire folder's contents to it as the initial commit on `main`.

   ```bash
   cd notification-service
   git init
   git add .
   git commit -m "Initial commit - notification-service"
   git branch -M main
   git remote add origin <your-repo-url>
   git push -u origin main
   ```

2. **Add Docker Hub credentials as GitHub Actions secrets**, since the workflow needs to authenticate to push images:
   - Go to your repo → Settings → Secrets and variables → Actions → New repository secret
   - Add a secret named `DOCKERHUB_USERNAME` with your Docker Hub username (`naveen352`)
   - Add a secret named `DOCKERHUB_TOKEN` with a Docker Hub access token (generate one at hub.docker.com → Account Settings → Security → New Access Token — don't use your account password)

3. That's it — no other setup required. GitHub Actions runners are fully hosted; you don't need to provision any infrastructure yourself.

## Ticket: PAYFLOW-3107

Two release attempts have failed to produce a usable image on Docker Hub since this workflow was merged. Investigate using the Actions run logs (repo → Actions tab → click the failed/problematic run → expand each step's logs).

Trigger a run by pushing any small change to `main`, or re-running the existing workflow from the Actions tab.


# PAYFLOW-3107 — Root Cause

**Issue:** `build-and-push` job failed at the "Log in to Docker Hub" step with `Error: Password required`.

**How it was found:** Opened the failed run in the GitHub Actions tab → expanded the "Log in to Docker Hub" step logs → saw the login action received no password.

**Root cause:** The workflow referenced `secrets.DOCKER_HUB_TOKEN`, but the actual repository secret was named `DOCKERHUB_TOKEN` (no underscore between DOCKER and HUB). A mismatched secret name doesn't throw a "secret not found" error — GitHub Actions silently resolves it to an empty string, which only surfaces later as whatever error the consuming tool gives for a missing value.

**Fix:** Corrected the secret reference in `ci-cd.yml`:
```yaml
password: ${{ secrets.DOCKERHUB_TOKEN }}
```

**Verification:** Re-ran the workflow — both jobs passed. Confirmed the image actually landed on Docker Hub via `docker pull naveen352/notification-service:latest` and checking the Tags page on hub.docker.com.