# Rick and Morty GKE DevOps System

> ⚡ **Looking for the Quickstart?** Jump straight to the [DevOps Quickstart Guide (TL;DR)](readmeTL;DR.md).

---

## Table of Contents
1. [Project Architecture](#project-architecture)
2. [Repository Structure](#repository-structure)
3. [Environment Configuration & Secrets](#environment-configuration--secrets)
4. [Application Core & CLI Tool](#application-core--cli-tool)
5. [Dockerization (Non-Root Image)](#dockerization-non-root-image)
6. [GCP Artifact Registry Setup](#gcp-artifact-registry-setup)
7. [Terraform Infrastructure Provisioning](#terraform-infrastructure-provisioning)
8. [Kubernetes & Helm Deployments](#kubernetes--helm-deployments)
9. [Automated Teardown & Cleanup](#automated-teardown--cleanup)
10. [CI/CD Pipeline (GitHub Actions)](#cicd-pipeline-github-actions)

---

## Project Architecture

The application fetches paginated data from the upstream Rick and Morty API, filters for characters that match:
- **Species**: `Human`
- **Status**: `Alive`
- **Origin**: Starts with `Earth` (e.g. `Earth (C-137)`, `Earth (Replacement Dimension)`)

### Key Improvements & Fixes Implemented:
* **Upstream Rate Limit Resilience**: Added a robust fetch mechanism (`get_with_retry` in `app/fetch.py`) utilizing exponential backoff (retrying on HTTP `429 Too Many Requests`) combined with a `0.1s` throttling delay between page requests.
* **Dockerfile Paths & Non-Root Execution**: Fixed typical container execution errors (`ModuleNotFoundError: No module named 'uvicorn'`) by installing Python dependencies to a dedicated `--prefix=/install` directory in the builder stage, and copying them to `/usr/local` in the runner stage. The application runs securely as a non-root system user (`appuser` with UID `10001`).
* **GKE Single-Node Optimization**: Provisioned GKE with a single `e2-medium` node to limit GCP billing costs. Because default configurations require high CPU limits, we optimized the Helm resource requests (`requests.cpu: 10m`, `requests.memory: 64Mi`) and limited deployment replicas to `1` to prevent resource allocation failures.
* **Unified Scripts**: Created `deploy.sh` and `destroy.sh` in the root folder to handle state synchronization, environment loading, and resource teardown sequencing.

---

## Repository Structure

```text
GKE-RickAndMorty-DevOps/
├── .github/
│   └── workflows/
│       └── pipeline.yml       # GitHub Actions pipeline (unit tests + Minikube deploy)
├── app/
│   ├── __init__.py
│   ├── main.py                # FastAPI web server serving healthcheck and filtered API
│   ├── fetch.py               # Characters fetcher, rate-limiter, and CSV exporter
│   ├── cli.py                 # CLI entry point to generate local results.csv
│   └── config.py              # Environment configuration loader
├── infra/
│   └── terraform/             # Terraform configuration files
│       ├── providers.tf       # Google provider settings
│       ├── backend.tf         # Remote state backend configuration
│       ├── variables.tf       # Input variables
│       ├── main.tf            # VPC, subnet, GKE cluster, and node pool resources
│       └── outputs.tf         # Connectivity outputs and resource IDs
├── helm/
│   └── backend/               # Helm Chart manifests
│       ├── Chart.yaml
│       ├── values.yaml        # CPU/Memory limits, container ports, replica counts
│       └── templates/         # Deployment, Service, Ingress, and Helpers
├── yamls/                     # Raw Kubernetes manifests (alternative deploy)
│   ├── Deployment.yaml
│   ├── Service.yaml
│   └── Ingress.yaml
├── logs/                      # App log directory (git-ignored)
├── secrets/                   # Protected config directory (git-ignored)
│   └── .env                   # Active environment variables
├── example.env                # Template configuration environment file
├── Dockerfile                 # Multi-stage secure non-root Docker build
├── docker-compose.yml         # Local docker-compose configurations
├── requirements.txt           # Python application dependencies
├── deploy.sh                  # One-click environment deploy automated script
├── destroy.sh                 # One-click environment teardown automated script
└── README.md                  # Detailed system documentation
```

---

## Environment Configuration & Secrets

Secrets and environment configurations must be loaded from `secrets/.env` (which is excluded from Git tracking).

### Setup Protocol:
1. Create the `secrets/` folder:
   ```bash
   mkdir -p secrets
   ```
2. Copy the template variables file:
   ```bash
   cp example.env secrets/.env
   ```
3. Open `secrets/.env` and configure your settings:
   - `GCP_PROJECT_ID`: Your target Google Cloud project ID.
   - `GCP_REGION` / `GCP_ZONE`: Selected GCP deployment targets (defaults: `us-central1` and `us-central1-a`).
   - `GCS_BUCKET_NAME`: GCS bucket used for storing Terraform remote state files.
   - `DOCKER_USERNAME` / `DOCKER_PASSWORD`: Docker registry access credentials.
   - `OWNER`: Your label identifier (e.g. `devops-user`).

---

## Application Core & CLI Tool

### Local Development Setup:
1. Create and source a virtual environment:
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   ```
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

### Executing CLI Tool:
Extract characters and generate `results.csv` in the root workspace folder:
```bash
python -m app.cli
```
This generates a `results.csv` file containing the headers: `Name`, `Location`, and `Image`.

### Executing FastAPI Web Server:
Start the server locally:
```bash
python -m app.main
```
The application will listen on the port configured in `.env` (default: `8080`).
- **Health check**: `GET http://127.0.0.1:8080/healthcheck`
- **Characters API**: `GET http://127.0.0.1:8080/characters`

### Running Unit Tests:
```bash
pytest -v
```

---

## Dockerization (Non-Root Image)

We build a optimized, multi-stage image running as a non-root system user.

### Local Docker Build & Compose:
To build and start the service locally using Docker Compose (which reads env parameters directly from `secrets/.env`):
```bash
docker compose --env-file secrets/.env up --build
```
Access the application at `http://localhost:8080/healthcheck`.

---

## GCP Artifact Registry Setup

The Kubernetes cluster pulls the application image securely from **GCP Artifact Registry**:

```bash
# Load environment configs
export $(grep -v '^#' secrets/.env | xargs)

# 1. Enable GCP Artifact Registry API
gcloud services enable artifactregistry.googleapis.com --project="$GCP_PROJECT_ID"

# 2. Create the Docker repository
gcloud artifacts repositories create app-repo \
    --repository-format=docker \
    --location="$GCP_REGION" \
    --project="$GCP_PROJECT_ID"

# 3. Authenticate Docker locally to GCP Registry
gcloud auth configure-docker "${GCP_REGION}-docker.pkg.dev" --quiet

# 4. Build, tag, and push the image
IMAGE_PATH="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/app-repo/rick-and-morty-app:latest"
docker build -t "$IMAGE_PATH" .
docker push "$IMAGE_PATH"
```

---

## Terraform Infrastructure Provisioning

Terraform manages the GCP VPC networks, subnets, and the GKE cluster. It uses a dynamic GCS backend to persist states remotely.

### Automated Provisioning:
Execute the wrapper deployment script from the root directory:
```bash
./deploy.sh
```
This script loads variables from `secrets/.env`, maps them to `TF_VAR_` prefixes, initializes the GCS backend configuration dynamically, and runs `terraform apply`.

### Configuring Kubectl Credentials:
Execute the connectivity command generated in the Terraform outputs to configure your local context:
```bash
# Load env and retrieve the credentials command dynamically
export $(grep -v '^#' secrets/.env | xargs)
$(cd infra/terraform && terraform output -raw gke_connectivity_command)
```

---

## Kubernetes & Helm Deployments

Ensure your `kubectl` context points to the GKE cluster.

### Deploying via Helm Chart:
```bash
helm upgrade --install backend ./helm/backend --values ./helm/backend/values.yaml
```

To verify the deployment resources:
```bash
kubectl get pods -l app.kubernetes.io/name=backend
kubectl get service backend-service
```

### Port Forwarding Tunnel (WSL/Local Port Collisions):
If port `8080` is in use by local services (e.g. PostgreSQL or Jenkins), either stop those local processes or map the tunnel to a free port:
```bash
# Start background port-forward from local port 8080 to service target port 80
kubectl port-forward service/backend-service 8080:80 &

# Query the running GKE service
curl http://127.0.0.1:8080/healthcheck
curl http://127.0.0.1:8080/characters
```

---

## Automated Teardown & Cleanup

To clean up resources and prevent unexpected Google Cloud billing charges, execute the teardown script:
```bash
./destroy.sh
```
> [!IMPORTANT]
> The `./destroy.sh` wrapper script executes a clean deletion sequence: it uninstalls the Helm release and deletes any ingress/service resources *first*. This allows GCP to detach and delete the external Cloud Load Balancers and release their public IP allocations, preventing Terraform network resources from getting locked or orphaned during `terraform destroy`.

---

## CI/CD Pipeline (GitHub Actions)

The repository includes a GitHub Actions configuration `.github/workflows/pipeline.yml` that executes on every pull request and push to the `main` or `master` branches.

### Pipeline Stage Details:
1. **Lint & Test**: Sets up a Python virtual environment, installs dependencies, and runs standard unit tests with `pytest`.
2. **Build Container**: Packages the application using the multi-stage Docker build.
3. **Local Cluster Orchestration**: Configures and spins up a local `Minikube` environment on the runner node.
4. **Local Deployment**: Loads the built Docker image directly into the Minikube registry and deploys the backend Helm release.
5. **Integration Verification**: Confirms pods are healthy, establishes a background port-forwarding tunnel, and uses `curl` to verify responses from both `/healthcheck` and `/characters` endpoints.
