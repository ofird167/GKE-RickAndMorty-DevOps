# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

# Subnetwork
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.gcp_region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "k8s-pod-range"
    ip_cidr_range = "10.4.0.0/14"
  }

  secondary_ip_range {
    range_name    = "k8s-service-range"
    ip_cidr_range = "10.8.0.0/20"
  }
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.gcp_zone

  deletion_protection = false

  # We can't auto-create subnets or use default networks for security
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  # Enable IP Alias
  ip_allocation_policy {
    cluster_secondary_range_name  = "k8s-pod-range"
    services_secondary_range_name = "k8s-service-range"
  }

  # We'll configure a custom node pool separately, so delete the default pool
  remove_default_node_pool = true
  initial_node_count       = 1

  # Apply labels for resource tagging/tracking
  resource_labels = {
    environment = var.environment
    owner       = var.owner
    managedby   = "terraform"
  }
}

# Custom Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.gcp_zone
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    # Metadata labels for nodes
    labels = {
      role        = "general"
      environment = var.environment
      owner       = var.owner
    }

    # Resource labels (tags) for VMs
    resource_labels = {
      environment = var.environment
      owner       = var.owner
      managedby   = "terraform"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
