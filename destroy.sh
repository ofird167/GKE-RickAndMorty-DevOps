#!/usr/bin/env bash
# Exit immediately if any command exits with a non-zero status
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Load environment variables
ENV_FILE="${PROJECT_ROOT}/secrets/.env"
if [ -f "$ENV_FILE" ]; then
  echo "Loading environment variables from $ENV_FILE..."
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  echo "Error: $ENV_FILE not found."
  exit 1
fi

# 2. Map variables for Terraform
export TF_VAR_gcp_project_id=$GCP_PROJECT_ID
export TF_VAR_gcp_region=$GCP_REGION
export TF_VAR_gcp_zone=$GCP_ZONE
export TF_VAR_gcs_bucket_name=$GCS_BUCKET_NAME
export TF_VAR_cluster_name=$CLUSTER_NAME
export TF_VAR_environment=$ENVIRONMENT
export TF_VAR_owner=$OWNER

# 3. Connect kubectl to GKE cluster (if GKE cluster is currently active)
echo "Attempting to configure kubectl context for GKE..."
if gcloud container clusters describe "$CLUSTER_NAME" --zone "$GCP_ZONE" --project "$GCP_PROJECT_ID" >/dev/null 2>&1; then
  gcloud container clusters get-credentials "$CLUSTER_NAME" --zone "$GCP_ZONE" --project "$GCP_PROJECT_ID"
  
  # 4. Clean up Kubernetes resources first to release GCP Load Balancers
  echo "Cleaning up Kubernetes resources (Ingress, Services, Helm releases)..."
  
  # Uninstall Helm release if present
  if helm list -A | grep -q "backend"; then
    echo "Uninstalling Helm release 'backend'..."
    helm uninstall backend || true
  fi

  # Delete raw manifests if present
  if [ -d "${PROJECT_ROOT}/yamls" ]; then
    echo "Deleting raw Kubernetes manifests..."
    kubectl delete -f "${PROJECT_ROOT}/yamls/" --ignore-not-found=true || true
  fi

  # Fallback: delete any leftover Ingress or LoadBalancer service in default namespace
  echo "Ensuring all LoadBalancer services and Ingresses are removed..."
  kubectl delete ingress --all --ignore-not-found=true || true
  kubectl delete svc -l app=backend --ignore-not-found=true || true

  # Give Google Cloud a few seconds to release public IP addresses and load balancer resources
  echo "Waiting 20 seconds for GCP Load Balancers to detach..."
  sleep 20
else
  echo "GKE cluster not found or already deleted. Proceeding directly to Terraform destroy."
fi

# 5. Navigate to Terraform directory
cd "${PROJECT_ROOT}/infra/terraform"

# 6. Initialize (if needed)
if [ ! -d ".terraform" ]; then
  terraform init \
    -backend-config="bucket=$GCS_BUCKET_NAME" \
    -backend-config="prefix=devops/gke/state"
fi

# 7. Destroy GCP Infrastructure
echo "Destroying GKE cluster and VPC network via Terraform..."
terraform destroy
