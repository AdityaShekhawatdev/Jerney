# Jerney — DevSecOps Implementation

> Forked from [iam-veeramalla/Jerney](https://github.com/iam-veeramalla/Jerney) — a 3-tier blog application (React + Vite frontend, Node.js/Express backend, PostgreSQL database).
>
> This repository documents my implementation of DevSecOps practices on top of the original app, built from scratch as a self-driven learning exercise.

## Table of Contents
- [Architecture](#architecture)
- [DevSecOps Practices Implemented](#devsecops-practices-implemented)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Security Decisions & Trade-offs](#security-decisions--trade-offs)

## Architecture

**Local (Docker Compose):**
```
[Browser] → [Nginx :8080 — serves React build, proxies /api/*] → [Node/Express backend :5000] → [PostgreSQL :5432]
```

**Kubernetes (local, via minikube + Helm):**
```
[Browser] → [Service: frontend (NodePort)] → [Nginx pod] → [Service: backend (ClusterIP)] → [Backend pod] → [Service: db (ClusterIP)] → [Postgres pod]
```
All three services run as separate containers/pods on an isolated network. The backend and database are never directly reachable from outside — only the frontend is exposed.

## DevSecOps Practices Implemented

### Build Stage (Docker)
- Multi-stage Docker builds for frontend and backend — dependency install happens in a `build` stage; the final `production` stage only carries `node_modules` + source code (backend) or the compiled static bundle (frontend), keeping build tools and npm cache out of the shipped image
- Non-root users in every container — custom `appuser` for the backend (`addgroup -S` / `adduser -S`, Alpine syntax), the built-in `nginx` user for the frontend (reused instead of duplicating)
- Minimal base images — `node:20-alpine`, `nginx:alpine`, `postgres:16-alpine`
- Production-only dependencies — `npm ci --only=production` in the backend, so devDependencies (eslint, nodemon) never ship in the image
- Deterministic installs — `npm ci` instead of `npm install`, so builds always use the exact versions locked in `package-lock.json`
- Images built and pushed to Docker Hub with semantic version tags (e.g. `v1.0.0`), avoiding the `latest` tag for traceability and safe rollbacks

### Orchestration — Docker Compose (local dev)
- `docker-compose.yml` wiring frontend, backend, and database with a shared Docker network — services reach each other by service name
- Healthcheck on Postgres (`pg_isready`) combined with `depends_on: condition: service_healthy`, so the backend waits for the database to actually accept connections
- Named volume (`db_data`) for PostgreSQL data persistence across container restarts
- Backend uses `expose` (internal-only) instead of `ports` — reachable from the frontend over the Docker network but not published to the host

### Orchestration — Kubernetes (local, via minikube + Helm)
- Single Helm chart covering all three services (backend, frontend, db) as sections in `values.yaml` — chosen over separate charts since this is a single tech stack, not a microservices architecture
- Deployments for backend, frontend, and db, each with CPU/memory `requests` and `limits` to prevent one pod from starving the node
- Services (`ClusterIP`) for internal DNS-based service discovery — e.g. the backend resolves the database via the `jerney-db` Service name, not a hardcoded IP
- Frontend exposed via NodePort for local access (a production setup would use an Ingress with a proper domain instead)
- Kubernetes Secret (`jerney-secret`) holding DB credentials, injected into pods via `secretKeyRef` — no plaintext credentials in any templated manifest
- Actual secret values kept in a separate, git-ignored `values-secret.yaml`, layered on top of the chart at install time with `helm install/upgrade -f values-secret.yaml` — the committed `values.yaml` and `templates/secret.yaml` never contain real credentials

### Secrets Management
- Database credentials moved out of source code — `.env` for Docker Compose, a git-ignored `values-secret.yaml` for Helm
- Both `.env` and `values-secret.yaml` are excluded via `.gitignore`; example/template files (`.env.example`, `values-secret.example.yaml`) are committed instead so the required keys are documented without exposing real values

### Network / Web Server Security
- Custom Nginx config with security headers: `X-Frame-Options`, `X-Content-Type-Options`, `X-XSS-Protection`, `Referrer-Policy`
- Dotfile access blocked at the Nginx level — requests to `.env`, `.git`, etc. return `404`
- Reverse proxy pattern — the backend is never directly exposed to the internet; all API traffic goes through Nginx's `/api/` location block, which also forwards real client IP and protocol headers
- Nginx runs on unprivileged port 8080 internally since non-root containers can't bind to ports below 1024

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | React, Vite, Nginx |
| Backend | Node.js, Express |
| Database | PostgreSQL |
| Containerization | Docker, Docker Compose |
| Orchestration | Kubernetes (minikube), Helm |

## Getting Started

### Option A — Docker Compose (simplest, local dev)

**Prerequisites:** Docker & Docker Compose

1. Clone the repository
   ```bash
   git clone <your-fork-url>
   cd Jerney
   ```
2. Create a `.env` file in the project root:
   ```
   DB_USER=your_db_user
   DB_PASSWORD=your_db_password
   DB_NAME=your_db_name
   ```
3. Build and start all services:
   ```bash
   docker compose up --build
   ```
4. Visit `http://localhost` in your browser.

### Option B — Kubernetes via Helm (minikube)

**Prerequisites:** minikube, kubectl, Helm

1. Start minikube and enable the ingress addon:
   ```bash
   minikube start
   minikube addons enable ingress
   ```
2. Load or push your images so the cluster can pull them (see chart's `values.yaml` for image names/tags).
3. Create `k8s/values-secret.yaml` (see `k8s/values-secret.example.yaml` for the required keys) with real DB credentials.
4. Install the chart:
   ```bash
   helm install jerney-release ./k8s -f ./k8s/values-secret.yaml
   ```
5. Access the app:
   ```bash
   minikube service jerney-frontend --url
   ```

## Security Decisions & Trade-offs

- **Port 8080 instead of 80 in Nginx:** Linux treats ports below 1024 as privileged — only root can bind to them by default. Since the container runs as the non-root `nginx` user (a deliberate hardening choice), Nginx listens on 8080 internally and Docker/Kubernetes map the external port to it.

- **`npm ci` instead of `npm install`:** `npm install` can silently update `package-lock.json` if versions drift, producing non-reproducible builds. `npm ci` installs strictly from the lock file and fails if it's missing or out of sync — the right behavior for CI/production builds where determinism matters more than convenience.

- **Backend uses `expose`/ClusterIP, never a public port:** The backend has no reason to be reachable directly from outside — all legitimate traffic should go through the frontend's reverse proxy. This reduces the attack surface; there's simply no public port to attack.

- **Multi-stage builds:** Build-time dependencies (npm cache, dev tools, and the Vite/Node toolchain used to produce the static bundle) don't belong in a production image — they add size and unnecessary attack surface. Each Dockerfile's final stage only contains what's needed to *run* the app, not *build* it.

- **NodePort instead of Ingress for local access:** This project shares a minikube cluster with another local project, and both wanted to bind the same wildcard host/path via Ingress, which the admission webhook rejected. Rather than force a host-based workaround, NodePort was used for local access; a real deployment would use Ingress with a proper, unique domain.

- **Secrets split into a separate values file:** Keeping real credentials out of `values.yaml` and `templates/secret.yaml` (which are committed to Git) avoids repeating the mistake of committing plaintext credentials — the same principle applied to `.env` in the Docker Compose setup.

---

*This project is part of my self-driven DevOps learning journey. Original application by [@iam-veeramalla](https://github.com/iam-veeramalla).*