output "gke_cluster_id" {
  value       = google_container_cluster.primary.id
  description = "The ID of the GKE Cluster."
}

output "gke_cluster_endpoint" {
  value       = google_container_cluster.primary.endpoint
  description = "The control plane endpoint for the GKE cluster."
}

output "gke_connectivity_command" {
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${google_container_cluster.primary.location} --project ${var.gcp_project_id}"
  description = "The gcloud command to configure kubectl credentials locally."
}

output "vpc_id" {
  value       = google_compute_network.vpc.id
  description = "The ID of the custom VPC network."
}

output "subnet_id" {
  value       = google_compute_subnetwork.subnet.id
  description = "The ID of the subnetwork."
}

output "gcs_state_bucket" {
  value       = var.gcs_bucket_name
  description = "The name of the GCS bucket used for state storage."
}
