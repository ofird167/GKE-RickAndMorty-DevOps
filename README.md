# Rick and Morty DevOps Home Exercise

This repository implements a complete end-to-end DevOps solution for filtering and serving characters from the **Rick and Morty API** on **Google Cloud Platform (GCP)**.

---

## Repository Structure

```text
interview7/
├── .github/
│   └── workflows/
│       └── pipeline.yml       # GitHub Actions workflow (CI/CD)
├── app/
│   ├── __init__.py
│   ├── main.py                # FastAPI web server
│   ├── fetch.py               # Rick & Morty API fetcher & CSV exporter logic
│   ├── cli.py                 # CLI entry point to generate results.csv
│   └── config.py              # Configuration loading from secrets/.env
├── infra/
│   └── terraform/
│       ├── providers.tf       # GCP provider configuration
│       ├── backend.tf         # GCS backend configuration for state
│       ├── variables.tf       # Terraform variable declarations
│       ├── main.tf            # Main resources (GKE cluster, VPC, subnets)
│       └── outputs.tf         # Terraform outputs
├── helm/
│   └── backend/               # Helm chart for the backend API service
│       ├── Chart.yaml         # Helm chart definition
│       ├── values.yaml        # Helm default values
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           └── _helpers.tpl
├── yamls/                     # Raw Kubernetes manifests
│   ├── Deployment.yaml
│   ├── Service.yaml
│   └── Ingress.yaml
├── logs/                      # Git-ignored application logs
├── secrets/                   # Git-ignored secrets folder
│   └── .env                   # Environment secrets config
├── example.env                # Template environment variables
├── .gitignore                 # Standard git ignore rules
├── Dockerfile                 # Multi-stage secure non-root Dockerfile
├── docker-compose.yml         # Docker Compose configuration
├── requirements.txt           # Python dependencies
└── README.md                  # This documentation guide
```

---

## 1. Environment Setup

Copy `example.env` from the root directory to `secrets/.env` and populate the values:

```bash
mkdir -p secrets
cp example.env secrets/.env
```

Ensure `secrets/.env` has correct values:
* `GCP_PROJECT_ID`: Your GCP Project ID (e.g. `devops-project`)
* `GCP_REGION`: The region for deploying resources (e.g. `us-central1`)
* `GCP_ZONE`: The zone for deploying GKE nodes (e.g. `us-central1-a`)
* `GCS_BUCKET_NAME`: The name of the GCS bucket for remote state (e.g. `devops-project-tfstate-bucket`)
* `DOCKER_USERNAME` / `DOCKER_PASSWORD`: Your Docker registry credentials
* `OWNER`: Your identifier label (e.g. `devops-user`)

---

## 2. Application Core (Python + FastAPI)

### Install Dependencies locally:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### CLI Execution
To run the extraction script, fetch all pages from the API, filter for characters where `Species == "Human"`, `Status == "Alive"`, and `Origin starts with "Earth"`, and save them to `results.csv`:
```bash
python -m app.cli
```
This writes `Name,Location,Image` fields into `results.csv`.

### Web Server Execution
To run the FastAPI server locally:
```bash
python -m app.main
```
Endpoints:
- `GET http://127.0.0.1:8080/characters` - Returns the filtered characters list in JSON.
- `GET http://127.0.0.1:8080/healthcheck` - Returns `{ "status": "healthy" }`.

### Run Unit Tests
```bash
pytest -v
```

---

## 3. Dockerization

### Docker Compose
To build and start the service locally using Docker Compose (which reads env parameters directly from `secrets/.env`):
```bash
docker compose --env-file secrets/.env up --build
```
Access the application at `http://localhost:8080/healthcheck`.

---

## 4. Terraform Infrastructure Provisioning

Follow this strict injection workflow to load configurations from `secrets/.env` and deploy GCP resources:

```bash
# 1. Load environment variables from secrets/.env
export $(grep -v '^#' secrets/.env | xargs)

# 2. Map variables with TF_VAR_ prefix
export TF_VAR_gcp_project_id=$GCP_PROJECT_ID
export TF_VAR_gcp_region=$GCP_REGION
export TF_VAR_gcp_zone=$GCP_ZONE
export TF_VAR_gcs_bucket_name=$GCS_BUCKET_NAME
export TF_VAR_cluster_name=$CLUSTER_NAME
export TF_VAR_environment=$ENVIRONMENT
export TF_VAR_owner=$OWNER

# 3. Navigate to terraform directory
cd infra/terraform

# 4. Initialize Terraform with dynamic GCS remote backend configuration
terraform init \
  -backend-config="bucket=$GCS_BUCKET_NAME" \
  -backend-config="prefix=devops/gke/state"

# 5. Run validation checks
terraform validate

# 6. Apply the Terraform plan
terraform apply
```

To configure local access to the created GKE cluster:
```bash
gcloud container clusters get-credentials $(terraform output -raw cluster_name) \
  --zone $(terraform output -raw gcp_zone) \
  --project $(terraform output -raw gcp_project_id)
```

---

## 5. Kubernetes & Helm Deployments

Ensure your `kubectl` context points to the target cluster.

### Deploying via Raw manifests (`yamls/`)
```bash
kubectl apply -f yamls/Deployment.yaml
kubectl apply -f yamls/Service.yaml
kubectl apply -f yamls/Ingress.yaml
```

### Deploying via Helm Chart (`helm/`)
```bash
helm upgrade --install backend ./helm/backend --values ./helm/backend/values.yaml
```

To verify the deployments:
```bash
kubectl get pods
kubectl get service backend-service
kubectl get ingress backend-ingress
```

---

## 6. GitHub Actions CI/CD Pipeline

The automated workflow is configured under `.github/workflows/pipeline.yml`.

### Key Jobs & Steps:
1. **Checkout & Test**: Pulls the repository, sets up Python 3.12, installs dependencies, and runs `pytest` unit tests.
2. **Build Docker Image**: Builds the lightweight, multi-stage secure container.
3. **Local Cluster Provisioning**: Spins up a local `Minikube` environment on the GHA runner.
4. **Load Image & Deploy**: Loads the Docker image into Minikube and deploys the Helm chart.
5. **Integration Checks**: Validates the running pods, port-forwards the service, and queries `/healthcheck` and `/characters` endpoints to verify success.
