# MEAN CRUD App - Dockerized Deployment

This repo contains a MEAN stack CRUD app (MongoDB, Express, Angular 15, Node.js) with Dockerized frontend/backend, Docker Compose deployment, GitHub Actions CI/CD, and Nginx reverse proxy on port 80.

## Repository Contents
- Backend Dockerfile: `backend/Dockerfile`
- Frontend Dockerfile: `frontend/Dockerfile`
- Root compose file: `docker-compose.yml`
- Nginx reverse proxy config (host): `deploy/nginx.conf`
- CI/CD workflow: `.github/workflows/ci-cd.yml`

## Prerequisites
- Docker Hub account: `guptalakshya`
- GitHub repo (this project) with `main` branch
- Ubuntu VM (EC2) with public IP `54.197.150.178`
- Inbound ports: `22`, `80` (and optionally `8080`, `4200` for debugging)

## Local Development (Optional)
Backend:
```bash
cd backend
npm install
node server.js
```

Frontend:
```bash
cd frontend
npm install
npm start
```

The frontend uses a relative API path (`/api`). The dev proxy is configured in `frontend/proxy.conf.json`.

## Docker (Local)
Build and run everything:
```bash
docker compose up --build
```

Services:
- Frontend: `http://localhost:4200`
- Backend: `http://localhost:8080`
- MongoDB: `localhost:27017`

## Docker Hub Images
Images built by CI:
- `guptalakshya/dd-backend:latest`
- `guptalakshya/dd-frontend:latest`

## EC2 Setup (Ubuntu)
Install Docker, Compose, and Nginx:
```bash
sudo apt update
sudo apt install -y docker.io docker-compose nginx
sudo usermod -aG docker $USER
```
Log out and back in to refresh group membership.

Clone repo on EC2:
```bash
git clone <YOUR_GITHUB_REPO_URL> /home/ubuntu/mean-devOps-Deployment
cd /home/ubuntu/mean-devOps-Deployment
```

Run containers:
```bash
docker compose pull
docker compose up -d
```

## Nginx Reverse Proxy (Host-Level)
Use the provided config to expose the app on port 80 (subdomain):
```bash
sudo cp /home/ubuntu/mean-devOps-Deployment/deploy/nginx.conf /etc/nginx/sites-available/mean-app
sudo ln -s /etc/nginx/sites-available/mean-app /etc/nginx/sites-enabled/mean-app
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

Now open:
- `http://mean.54.197.150.178.sslip.io/`

## CI/CD (GitHub Actions)
Workflow file: `.github/workflows/ci-cd.yml`

### Required GitHub Secrets
- `DOCKERHUB_USERNAME` = `guptalakshya`
- `DOCKERHUB_TOKEN` = Docker Hub access token
- `EC2_HOST` = `54.197.150.178`
- `EC2_USER` = `ubuntu`
- `EC2_SSH_KEY` = private key used for EC2 SSH

### What the pipeline does
1. Builds and pushes Docker images on every push to `main`.
2. SSHs to EC2, pulls latest images, and restarts containers.

## Screenshots (Required by Task)
Add screenshots under `docs/screenshots/` and update this list:
- CI/CD workflow config and execution
- Docker image build and push process
- Application deployment and working UI
- Nginx setup and infrastructure details

Suggested filenames:
- `docs/screenshots/ci-workflow.png`
- `docs/screenshots/ci-run.png`
- `docs/screenshots/dockerhub-images.png`
- `docs/screenshots/app-ui.png`
- `docs/screenshots/nginx-setup.png`

## Notes
- The backend reads Mongo URL from `MONGODB_URL` environment variable in `docker-compose.yml`.
- The frontend calls the API via `/api`, which is routed by Nginx to the backend.
