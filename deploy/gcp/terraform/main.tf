# ==============================================================================
# Heretek OpenClaw - GCP Terraform Configuration
# ==============================================================================
# Main configuration file for GCP infrastructure
# ==============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  backend "gcs" {
    # Configure backend with variables or environment
    # bucket = "terraform-state-bucket"
    # prefix = "openclaw/terraform.tfstate"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.openclaw_cluster.endpoint}"
  token                  = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.openclaw_cluster.master_auth[0].cluster_ca_certificate[0])
}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.openclaw_cluster.endpoint}"
    token                  = data.google_client_config.current.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.openclaw_cluster.master_auth[0].cluster_ca_certificate[0])
  }
}

# ==============================================================================
# Data Sources
# ==============================================================================

data "google_client_config" "current" {}

data "google_project" "project" {
  project_id = var.project_id
}

# ==============================================================================
# Local Values
# ==============================================================================

locals {
  name_prefix = "openclaw-${var.environment}"
  
  common_tags = {
    project     = "openclaw"
    environment = var.environment
    version     = var.app_version
    managed_by  = "terraform"
  }

  gpu_enabled = var.enable_gpu_support
  
  # Artifact Registry URLs
  artifact_registry_urls = {
    gateway = "${var.region}-docker.pkg.dev/${var.project_id}/${local.name_prefix}-registry/openclaw-gateway"
    litellm = "${var.region}-docker.pkg.dev/${var.project_id}/${local.name_prefix}-registry/litellm-proxy"
  }
}

# ==============================================================================
# Random Resources
# ==============================================================================

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# ==============================================================================
# VPC Network
# ==============================================================================

module "vpc" {
  source = "./vpc"

  project_id          = var.project_id
  network_name        = "${local.name_prefix}-vpc"
  region              = var.region
  zones               = var.zones
  vpc_cidr            = var.vpc_cidr
  subnets             = var.subnets
  enable_flow_logs    = var.enable_vpc_flow_logs
  enable_private_google_access = var.enable_private_google_access

  tags = local.common_tags
}

# ==============================================================================
# GKE Cluster
# ==============================================================================

module "gke" {
  source = "./gke"

  project_id        = var.project_id
  cluster_name      = "${local.name_prefix}-gke"
  location          = var.region
  zones             = var.zones
  network           = module.vpc.network_name
  subnetwork        = module.vpc.subnet_name
  ip_range_pods     = "${local.name_prefix}-pods"
  ip_range_services = "${local.name_prefix}-services"
  
  # GKE configuration
  kubernetes_version = var.gke_version
  release_channel    = var.gke_release_channel
  
  # Node pool configuration
  node_pools         = var.node_pools
  gpu_enabled        = local.gpu_enabled
  gpu_node_pool      = var.gpu_node_pool
  
  # Security
  enable_workload_identity = var.enable_workload_identity
  enable_private_cluster   = var.enable_private_cluster
  
  # Monitoring
  enable_monitoring = true
  enable_logging    = true

  tags = local.common_tags
}

# ==============================================================================
# Cloud SQL PostgreSQL
# ==============================================================================

module "cloud_sql" {
  source = "./cloud-sql"

  project_id           = var.project_id
  instance_name        = "${local.name_prefix}-pg"
  region               = var.region
  network              = module.vpc.network_name
  
  # Database configuration
  database_version     = var.postgresql_version
  tier                 = var.db_tier
  disk_size            = var.db_disk_size
  disk_type            = var.db_disk_type
  
  # Authentication
  database_name        = var.db_name
  database_user        = var.db_user
  database_password    = var.db_password
  
  # High availability
  high_availability    = var.db_high_availability
  backup_enabled       = var.db_backup_enabled
  backup_start_time    = var.db_backup_start_time
  point_in_time_recovery = var.db_point_in_time_recovery
  
  # Insights
  query_insights_enabled = var.db_query_insights_enabled

  tags = local.common_tags
}

# ==============================================================================
# Memorystore Redis
# ==============================================================================

module "memorystore" {
  source = "./memorystore"

  project_id     = var.project_id
  instance_id    = "${local.name_prefix}-redis"
  region         = var.region
  network        = module.vpc.network_name
  
  # Redis configuration
  tier           = var.redis_tier
  memory_size_gb = var.redis_memory_size_gb
  redis_version  = var.redis_version
  
  # High availability
  replica_count  = var.redis_replica_count
  read_replicas_enabled = var.redis_read_replicas_enabled
  
  # Security
  auth_enabled   = var.redis_auth_enabled
  auth_string    = var.redis_auth_string
  transit_encryption_enabled = var.redis_transit_encryption_enabled

  tags = local.common_tags
}

# ==============================================================================
# Artifact Registry
# ==============================================================================

module "artifact_registry" {
  source = "./artifact-registry"

  project_id   = var.project_id
  location     = var.region
  repository_name = "${local.name_prefix}-registry"
  format       = "DOCKER"
  
  # Cleanup policy
  cleanup_policy_days = var.artifact_cleanup_policy_days

  tags = local.common_tags
}

# ==============================================================================
# Cloud Load Balancing
# ==============================================================================

module "load_balancer" {
  source = "./load-balancer"

  project_id   = var.project_id
  region       = var.region
  network      = module.vpc.network_name
  subnet       = module.vpc.subnet_name
  
  # Load balancer configuration
  name         = "${local.name_prefix}-lb"
  
  # Backend services
  backend_services = [
    {
      name        = "openclaw-gateway"
      port        = 18789
      health_check_path = "/health"
    },
    {
      name        = "litellm-proxy"
      port        = 4000
      health_check_path = "/health"
    }
  ]
  
  # SSL certificate
  ssl_certificate_arn = var.ssl_certificate_arn
  managed_domain = var.managed_domain

  tags = local.common_tags
}

# ==============================================================================
# Monitoring
# ==============================================================================

module "monitoring" {
  source = "../terraform/modules/monitoring"

  name_prefix      = local.name_prefix
  project_id       = var.project_id
  gke_cluster_name = google_container_cluster.openclaw_cluster.name
  cloud_sql_instance = module.cloud_sql.instance_name
  memorystore_instance = module.memorystore.instance_id
  
  # Dashboard
  enable_dashboard = true
  
  # Alerts
  enable_alerts    = var.enable_monitoring_alerts
  alert_email      = var.alert_email

  tags = local.common_tags
}

# ==============================================================================
# Outputs
# ==============================================================================

output "network_name" {
  description = "VPC network name"
  value       = module.vpc.network_name
}

output "subnet_name" {
  description = "Subnet name"
  value       = module.vpc.subnet_name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.openclaw_cluster.endpoint
}

output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.openclaw_cluster.name
}

output "cloud_sql_connection_name" {
  description = "Cloud SQL connection name"
  value       = module.cloud_sql.connection_name
}

output "cloud_sql_private_ip" {
  description = "Cloud SQL private IP"
  value       = module.cloud_sql.private_ip
}

output "memorystore_host" {
  description = "Memorystore Redis host"
  value       = module.memorystore.host
}

output "memorystore_port" {
  description = "Memorystore Redis port"
  value       = module.memorystore.port
}

output "artifact_registry_url" {
  description = "Artifact Registry URL"
  value       = local.artifact_registry_urls
}

output "load_balancer_ip" {
  description = "Load balancer IP address"
  value       = module.load_balancer.ip_address
}
