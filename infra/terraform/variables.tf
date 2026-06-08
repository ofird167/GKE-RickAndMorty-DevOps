variable "gcp_project_id" {
  type        = string
  description = "The GCP Project ID where resources will be provisioned."
}

variable "gcp_region" {
  type        = string
  description = "The region to provision resources (e.g., us-central1)."
}

variable "gcp_zone" {
  type        = string
  description = "The zone to provision resources (e.g., us-central1-a)."
}

variable "gcs_bucket_name" {
  type        = string
  description = "The name of the GCS bucket for Terraform remote state."
}

variable "cluster_name" {
  type        = string
  description = "The name of the GKE cluster."
}

variable "environment" {
  type        = string
  description = "The deployment environment (e.g., dev, prod)."
}

variable "owner" {
  type        = string
  description = "The owner/creator tag for resources."
}
