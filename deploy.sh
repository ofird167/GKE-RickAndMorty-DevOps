#!/usr/bin/env bash
# Exit immediately if any command exits with a non-zero status
set -e

# Define root directory (where secrets/.env is located)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Load environment variables from secrets/.env
ENV_FILE="${PROJECT_ROOT}/secrets/.env"
if [ -f "$ENV_FILE" ]; then
  echo "Loading environment variables from $ENV_FILE..."
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  echo "Error: $ENV_FILE not found. Please create it using example.env as a reference."
  exit 1
fi

# 2. Map environment variables to TF_VAR_ variables for Terraform
export TF_VAR_gcp_project_id=$GCP_PROJECT_ID
export TF_VAR_gcp_region=$GCP_REGION
export TF_VAR_gcp_zone=$GCP_ZONE
export TF_VAR_gcs_bucket_name=$GCS_BUCKET_NAME
export TF_VAR_cluster_name=$CLUSTER_NAME
export TF_VAR_environment=$ENVIRONMENT
export TF_VAR_owner=$OWNER

# 3. Navigate to Terraform directory
cd "${PROJECT_ROOT}/infra/terraform"

# 4. Initialize Terraform with dynamic GCS remote backend
echo "Initializing Terraform with remote GCS state..."
terraform init \
  -backend-config="bucket=$GCS_BUCKET_NAME" \
  -backend-config="prefix=devops/gke/state"

# 5. Apply the plan
echo "Applying Terraform infrastructure changes..."
terraform apply
