terraform {
  backend "gcs" {
    # Configuration will be supplied dynamically via -backend-config flags during 'terraform init'
    # e.g., -backend-config="bucket=<bucket_name>" -backend-config="prefix=devops/gke/state"
  }
}
