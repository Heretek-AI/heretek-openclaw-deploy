# ==============================================================================
# Heretek OpenClaw - GCP GKE Configuration
# ==============================================================================
# Google Kubernetes Engine cluster for OpenClaw
# ==============================================================================

# ------------------------------------------------------------------------------
# GKE Cluster
# ------------------------------------------------------------------------------

resource "google_container_cluster" "openclaw_cluster" {
  name     = var.cluster_name
  location = var.location
  project  = var.project_id

  # Node locations (for regional clusters)
  node_locations = var.zones

  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  # Network configuration
  network    = var.network
  subnetwork = var.subnetwork

  # IP allocation policy (VPC-native cluster)
  ip_allocation_policy {
    cluster_secondary_range_name  = var.ip_range_pods
    services_secondary_range_name = var.ip_range_services
  }

  # Private cluster configuration
  dynamic "private_cluster_config" {
    for_each = var.enable_private_cluster ? [1] : []
    content {
      enable_private_nodes    = true
      enable_private_endpoint = false
      master_ipv4_cidr_block  = "172.16.0.0/28"
    }
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Release channel
  release_channel {
    channel = var.gke_release_channel
  }

  # Kubernetes version
  min_master_version = var.gke_version

  # Cluster addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
    gcp_filestore_csi_driver_config {
      enabled = true
    }
  }

  # Network policy
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Master authorized networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "all-networks"
    }
  }

  # Logging and monitoring
  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS"
    ]
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS"
    ]
    managed_prometheus {
      enabled = true
    }
  }

  # Security
  resource_labels = var.tags

  lifecycle {
    ignore_changes = [
      node_config,
      node_version
    ]
  }
}

# ------------------------------------------------------------------------------
# General Purpose Node Pool
# ------------------------------------------------------------------------------

resource "google_container_node_pool" "general" {
  name       = "${var.cluster_name}-general"
  location   = var.location
  project    = var.project_id
  cluster    = google_container_cluster.openclaw_cluster.name
  node_count = var.node_pools.general.initial_count

  autoscaling {
    min_node_count = var.node_pools.general.min_count
    max_node_count = var.node_pools.general.max_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.node_pools.general.machine_type
    disk_size_gb = var.node_pools.general.disk_size_gb
    disk_type    = var.node_pools.general.disk_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = merge(var.tags, {
      workload-type = "general"
    })

    tags = ["openclaw-node"]

    workload_metadata_config {
      mode = "GKE_WORKLOAD_IDENTITY"
    }
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  lifecycle {
    ignore_changes = [
      node_count
    ]
  }
}

# ------------------------------------------------------------------------------
# Compute Optimized Node Pool
# ------------------------------------------------------------------------------

resource "google_container_node_pool" "compute" {
  name       = "${var.cluster_name}-compute"
  location   = var.location
  project    = var.project_id
  cluster    = google_container_cluster.openclaw_cluster.name
  node_count = var.node_pools.compute.initial_count

  autoscaling {
    min_node_count = var.node_pools.compute.min_count
    max_node_count = var.node_pools.compute.max_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.node_pools.compute.machine_type
    disk_size_gb = var.node_pools.compute.disk_size_gb
    disk_type    = var.node_pools.compute.disk_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = merge(var.tags, {
      workload-type = "compute"
    })

    tags = ["openclaw-node"]

    workload_metadata_config {
      mode = "GKE_WORKLOAD_IDENTITY"
    }
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  lifecycle {
    ignore_changes = [
      node_count
    ]
  }
}

# ------------------------------------------------------------------------------
# GPU Node Pool (Optional)
# ------------------------------------------------------------------------------

resource "google_container_node_pool" "gpu" {
  count = var.gpu_enabled ? 1 : 0

  name       = "${var.cluster_name}-gpu"
  location   = var.location
  project    = var.project_id
  cluster    = google_container_cluster.openclaw_cluster.name
  node_count = var.gpu_node_pool.initial_count

  autoscaling {
    min_node_count = var.gpu_node_pool.min_count
    max_node_count = var.gpu_node_pool.max_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.gpu_node_pool.machine_type
    disk_size_gb = var.gpu_node_pool.disk_size_gb
    disk_type    = "pd-ssd"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = merge(var.tags, {
      workload-type = "gpu"
      gpu           = "true"
    })

    tags = ["openclaw-gpu-node"]

    guest_accelerator {
      type  = var.gpu_node_pool.accelerator_type
      count = var.gpu_node_pool.accelerator_count
    }

    workload_metadata_config {
      mode = "GKE_WORKLOAD_IDENTITY"
    }
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  lifecycle {
    ignore_changes = [
      node_count
    ]
  }
}

# ------------------------------------------------------------------------------
# IAM for Service Account (Workload Identity)
# ------------------------------------------------------------------------------

resource "google_service_account" "openclaw" {
  account_id   = "${var.cluster_name}-sa"
  display_name = "OpenClaw GKE Service Account"
  project      = var.project_id
}

resource "google_project_iam_member" "openclaw_workload_identity" {
  project = var.project_id
  role    = "roles/workloadidentity.user"
  member  = "serviceAccount:${var.project_id}.svc.id.goog[openclaw/openclaw-sa]"
}

# ------------------------------------------------------------------------------
# GKE Secondary IP Ranges
# ------------------------------------------------------------------------------

resource "google_compute_subnetwork" "secondary_ranges" {
  name                     = "${var.network}-secondary"
  project                  = var.project_id
  region                   = var.location
  network                  = var.network
  ip_cidr_range            = "10.1.0.0/16"
  secondary_ip_range {
    range_name    = var.ip_range_pods
    ip_cidr_range = "10.2.0.0/16"
  }
  secondary_ip_range {
    range_name    = var.ip_range_services
    ip_cidr_range = "10.3.0.0/16"
  }
}

# ------------------------------------------------------------------------------
# GPU Plugin Installation (via Helm)
# ------------------------------------------------------------------------------

resource "helm_release" "nvidia_device_plugin" {
  count = var.gpu_enabled ? 1 : 0

  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  version    = "0.14.1"
  namespace  = "kube-system"

  set {
    name  = "config.map.name"
    value = "nvidia-device-plugin-config"
  }
}
