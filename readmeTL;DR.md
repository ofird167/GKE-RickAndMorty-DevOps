# DevOps Quickstart Guide (TL;DR)

Follow these steps to deploy, test, and teardown the entire GKE DevOps environment on GCP.

---

### 1. Setup Environment Variables
Create the `secrets/` directory and configure your `.env` variables:
1. Create a directory named `secrets/` at the root of the project:
   ```bash
   mkdir -p secrets
   ```
2. Copy `example.env` to `secrets/.env`:
   ```bash
   cp example.env secrets/.env
   ```
3. Populate all fields in `secrets/.env` (GCP Project ID, GCS state bucket, registry username/password, and owner label).

---

### 2. Provision GCP Infrastructure & GKE
Run the deployment automation wrapper script from the root:
```bash
./deploy.sh
```
*(This script loads the variables, maps them to `TF_VAR_` prefixes, initializes the Terraform GCS remote backend, and applies the configuration to create the VPC network, subnets, and GKE cluster).*

After the cluster is provisioned, configure your local `kubectl` to connect using the dynamically output command:
```bash
# Load env variables and execute the GKE connectivity command from Terraform output
export $(grep -v '^#' secrets/.env | xargs)
$(cd infra/terraform && terraform output -raw gke_connectivity_command)
```

---

### 3. Build & Push Docker Image (GCP Artifact Registry)
Build the image and push it to the private Google Artifact Registry repository:
```bash
# Load env variables
export $(grep -v '^#' secrets/.env | xargs)

# Authenticate Docker daemon to the regional registry
gcloud auth configure-docker "${GCP_REGION}-docker.pkg.dev" --quiet

# Build and tag
IMAGE_PATH="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/app-repo/rick-and-morty-app:latest"
docker build -t "$IMAGE_PATH" .

# Push image to GCP Artifact Registry
docker push "$IMAGE_PATH"
```

---

### 4. Deploy Application via Helm
Deploy the Helm release into the GKE cluster:
```bash
helm upgrade --install backend ./helm/backend --values ./helm/backend/values.yaml
```

---

### 5. Access and Test Endpoints (Local Tunnel)
If port `8080` is in use by local processes (like local PostgreSQL or Jenkins), either stop those services or forward the port to an alternative free port.

Establish the secure port-forward tunnel:
```bash
kubectl port-forward service/backend-service 8080:80
```

In a separate terminal tab/window, query the app endpoints:
*   **Health Check**: `curl http://127.0.0.1:8080/healthcheck`
*   **Filter Characters API**: `curl http://127.0.0.1:8080/characters`

---

### 6. Teardown & Clean Up
To destroy all GKE workloads, GCP Load Balancer instances, and networks safely to avoid unexpected GCP billing charges:
```bash
./destroy.sh
```
*(Note: `./destroy.sh` automatically uninstalls the Helm release and Kubernetes resources first to ensure GCP releases the load balancers, then runs `terraform destroy` to tear down the cluster and VPC network).*
