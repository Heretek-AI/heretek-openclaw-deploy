# ==============================================================================
# Heretek OpenClaw - GCP Terraform Outputs
# ==============================================================================
# Output values for GCP infrastructure
# ==============================================================================

# ------------------------------------------------------------------------------
# VPC Outputs
# ------------------------------------------------------------------------------

output "network_name" {
  description = "VPC network name"
  value       = module.vpc.network_name
}

output "network_self_link" {
  description = "VPC network self link"
  value       = module.vpc.network_self_link
}

output "subnet_name" {
  description = "Primary subnet name"
  value       = module.vpc.subnet_name
}

output "subnet_self_link" {
  description = "Primary subnet self link"
  value       = module.vpc.subnet_self_link
}

# ------------------------------------------------------------------------------
# GKE Outputs
# ------------------------------------------------------------------------------

output "gke_cluster_id" {
  description = "GKE cluster ID"
  value       = google_container_cluster.openclaw_cluster.id
}

output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.openclaw_cluster.name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.openclaw_cluster.endpoint
  sensitive   = true
}

output "gke_cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.openclaw_cluster.master_auth[0].cluster_ca_certificate[0]
  sensitive   = true
}

output "gke_cluster_location" {
  description = "GKE cluster location"
  value       = google_container_cluster.openclaw_cluster.location
}

output "gke_cluster_node_count" {
  description = "GKE cluster node count"
  value       = google_container_cluster.openclaw_cluster.node_count
}

output "gke_cluster_node_pools" {
  description = "GKE cluster node pool names"
  value       = google_container_cluster.openclaw_cluster.node_pools
}

output "gke_workload_identity_pool" {
  description = "Workload Identity pool"
  value       = "${var.project_id}.svc.id.goog"
}

output "gke_kubeconfig_command" {
  description = "Command to get cluster credentials"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.openclaw_cluster.name} --region ${var.region} --project ${var.project_id}"
}

# ------------------------------------------------------------------------------
# Cloud SQL Outputs
# ------------------------------------------------------------------------------

output "cloud_sql_instance_id" {
  description = "Cloud SQL instance ID"
  value       = module.cloud_sql.instance_id
}

output "cloud_sql_instance_name" {
  description = "Cloud SQL instance name"
  value       = module.cloud_sql.instance_name
}

output "cloud_sql_connection_name" {
  description = "Cloud SQL connection name"
  value       = module.cloud_sql.connection_name
}

output "cloud_sql_private_ip" {
  description = "Cloud SQL private IP address"
  value       = module.cloud_sql.private_ip
}

output "cloud_sql_public_ip" {
  description = "Cloud SQL public IP address"
  value       = module.cloud_sql.public_ip
}

output "cloud_sql_database_name" {
  description = "Cloud SQL database name"
  value       = module.cloud_sql.database_name
}

output "cloud_sql_database_user" {
  description = "Cloud SQL database user"
  value       = module.cloud_sql.database_user
  sensitive   = true
}

output "cloud_sql_connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${module.cloud_sql.database_user}:${var.db_password}@${module.cloud_sql.private_ip}:5432/${module.cloud_sql.database_name}"
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Memorystore Outputs
# ------------------------------------------------------------------------------

output "memorystore_instance_id" {
  description = "Memorystore instance ID"
  value       = module.memorystore.instance_id
}

output "memorystore_host" {
  description = "Memorystore Redis host"
  value       = module.memorystore.host
}

output "memorystore_port" {
  description = "Memorystore Redis port"
  value       = module.memorystore.port
}

output "memorystore_connection_string" {
  description = "Redis connection string"
  value       = "redis://${var.redis_auth_enabled && var.redis_auth_string != null ? ":${var.redis_auth_string}@" : ""}${module.memorystore.host}:${module.memorystore.port}"
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Artifact Registry Outputs
# ------------------------------------------------------------------------------

output "artifact_registry_name" {
  description = "Artifact Registry name"
  value       = module.artifact_registry.repository_name
}

output "artifact_registry_url" {
  description = "Artifact Registry URL"
  value       = local.artifact_registry_urls
}

output "artifact_registry_docker_config" {
  description = "Docker configuration for Artifact Registry"
  value       = "gcloud auth configure-docker ${var.region}-docker.pkg.dev"
}

# ------------------------------------------------------------------------------
# Load Balancer Outputs
# ------------------------------------------------------------------------------

output "load_balancer_name" {
  description = "Load balancer name"
  value       = module.load_balancer.name
}

output "load_balancer_ip" {
  description = "Load balancer IP address"
  value       = module.load_balancer.ip_address
}

output "load_balancer_self_link" {
  description = "Load balancer self link"
  value       = module.load_balancer.self_link
}

# ------------------------------------------------------------------------------
# Monitoring Outputs
# ------------------------------------------------------------------------------

output "monitoring_dashboard_id" {
  description = "Cloud Monitoring dashboard ID"
  value       = module.monitoring.dashboard_id
}

output "monitoring_alert_policies" {
  description = "List of alert policy IDs"
  value       = module.monitoring.alert_policy_ids
}

# ------------------------------------------------------------------------------
# Cost Estimation
# ------------------------------------------------------------------------------

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    gke_cluster         = "~$73 (cluster management fee)"
    gke_nodes_general   = "~$${var.node_pools.general.initial_count * 140} (${var.node_pools.general.machine_type})"
    gke_nodes_compute   = "~$${var.node_pools.compute.initial_count * 300} (${var.node_pools.compute.machine_type})"
    gke_nodes_gpu       = local.gpu_enabled ? "~$${var.gpu_node_pool.initial_count * 1500} (${var.gpu_node_pool.machine_type})" : "$0"
    cloud_sql           = "~$${var.db_high_availability ? 300 : 150} (${var.db_tier})"
    memorystore         = "~$${var.redis_tier == "STANDARD_HA" ? 150 : 75} (${var.redis_memory_size_gb}GB)"
    load_balancer       = "~$18"
    artifact_registry   = "~$5 (storage)"
    cloud_monitoring    = "~$50"
    network_egress      = "Variable"
    total_estimate      = "See GCP Pricing Calculator for accurate pricing"
  }
}
