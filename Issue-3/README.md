# PAYFLOW-3107 — notification-service CI/CD

**Priority:** P2
**Component:** GitHub Actions — `notification-service`
**Status:** Resolved

---

## 🎫 The Ticket

**Company:** PayFlow — fintech company (same org as PAYFLOW-2298).

**Service:** `notification-service` — a Flask microservice that sends transaction alerts to merchants via webhook callbacks. Built and pushed to Docker Hub via GitHub Actions on every push to `main`, standardized on GitHub-native CI/CD for new greenfield services.

**What changed:** A junior engineer set up the initial `.github/workflows/ci-cd.yml` based on a template from another team's repo, and it merged to `main` after a light-touch review ("it's just CI config").

**What happened:** Since merging, **two separate release attempts** failed to produce a usable image on Docker Hub.

**Objective:** Get the workflow to reliably build, test, and push `notification-service` to Docker Hub on every push to `main`, with a working, pullable image tag. Investigate using the Actions run logs, not guesswork.

---

## 🚀 Deploy / Setup

```bash
cd notification-service
git init
git add .
git commit -m "Initial commit - notification-service"
git branch -M main
git remote add origin <your-repo-url>
git push -u origin main
```

**Add two GitHub Actions secrets** (repo → Settings → Secrets and variables → Actions):
- `DOCKERHUB_USERNAME` — your Docker Hub username
- `DOCKERHUB_TOKEN` — a Docker Hub access token (Read & Write scope, not your account password)

No cluster, no cloud account — GitHub Actions runners are fully hosted.

---

## 🔍 Commands to Start Investigating

- Repo → **Actions** tab → click the failed run → expand each step's logs, particularly the **"Log in to Docker Hub"** step.
- Trigger a fresh run by pushing any small change to `main`, or re-running from the Actions tab.

---

## ✅ Solution

**Issue:** `build-and-push` job failed at "Log in to Docker Hub" with `Error: Password required`.

**Root cause:** The workflow referenced `secrets.DOCKER_HUB_TOKEN`, but the actual repository secret was named `DOCKERHUB_TOKEN` (no underscore between DOCKER and HUB). A mismatched secret name doesn't throw a "secret not found" error — GitHub Actions silently resolves it to an empty string, which only surfaces downstream as whatever error the consuming tool gives for a missing value.

**Fix:**
```yaml
password: ${{ secrets.DOCKERHUB_TOKEN }}
```

**Verification:** Re-ran the workflow — both jobs passed. Confirmed the image actually landed via `docker pull naveen352/notification-service:latest` and checking the Tags page on hub.docker.com.

---

## 📎 Additional Notes

Docker Hub **auto-creates** the target repository on first successful push, as long as the credentials used have write access — worth explicitly checking the resulting repo's visibility (public/private) afterward rather than assuming it defaults to what you want.