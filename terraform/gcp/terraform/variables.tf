# ==============================================================================
# Heretek OpenClaw - GCP Terraform Variables
# ==============================================================================
# Input variables for GCP infrastructure
# ==============================================================================

# ------------------------------------------------------------------------------
# General Configuration
# ------------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zones" {
  description = "GCP zones for regional distribution"
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b", "us-central1-c"]
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "app_version" {
  description = "Application version to deploy"
  type        = string
  default     = "2026.3.28"
}

# ------------------------------------------------------------------------------
# VPC Configuration
# ------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnets" {
  description = "Subnet configurations"
  type = list(object({
    name          = string
    ip_cidr_range = string
    region        = string
  }))
  default = [
    {
      name          = "openclaw-subnet-1"
      ip_cidr_range = "10.0.1.0/24"
      region        = "us-central1"
    },
    {
      name          = "openclaw-subnet-2"
      ip_cidr_range = "10.0.2.0/24"
      region        = "us-central1"
    },
    {
      name          = "openclaw-subnet-3"
      ip_cidr_range = "10.0.3.0/24"
      region        = "us-central1"
    }
  ]
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "enable_private_google_access" {
  description = "Enable Private Google Access"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# GKE Configuration
# ------------------------------------------------------------------------------

variable "gke_version" {
  description = "GKE Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "gke_release_channel" {
  description = "GKE release channel (regular, rapid, stable)"
  type        = string
  default     = "regular"
  
  validation {
    condition     = contains(["regular", "rapid", "stable"], var.gke_release_channel)
    error_message = "Release channel must be one of: regular, rapid, stable."
  }
}

variable "node_pools" {
  description = "GKE node pool configurations"
  type = object({
    general = object({
      machine_type   = string
      min_count      = number
      max_count      = number
      initial_count  = number
      disk_size_gb   = number
      disk_type      = string
    })
    compute = object({
      machine_type   = string
      min_count      = number
      max_count      = number
      initial_count  = number
      disk_size_gb   = number
      disk_type      = string
    })
  })
  default = {
    general = {
      machine_type  = "n2-standard-4"
      min_count     = 1
      max_count     = 4
      initial_count = 2
      disk_size_gb  = 100
      disk_type     = "pd-ssd"
    }
    compute = {
      machine_type  = "c2-standard-8"
      min_count     = 1
      max_count     = 8
      initial_count = 2
      disk_size_gb  = 200
      disk_type     = "pd-ssd"
    }
  }
}

variable "enable_gpu_support" {
  description = "Enable GPU node pool for Ollama"
  type        = bool
  default     = false
}

variable "gpu_node_pool" {
  description = "GPU node pool configuration"
  type = object({
    machine_type   = string
    accelerator_type = string
    accelerator_count = number
    min_count      = number
    max_count      = number
    initial_count  = number
    disk_size_gb   = number
  })
  default = {
    machine_type      = "g2-standard-4"
    accelerator_type  = "nvidia-l4"
    accelerator_count = 1
    min_count         = 0
    max_count         = 4
    initial_count     = 1
    disk_size_gb      = 200
  }
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity"
  type        = bool
  default     = true
}

variable "enable_private_cluster" {
  description = "Enable private GKE cluster"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Cloud SQL PostgreSQL Configuration
# ------------------------------------------------------------------------------

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "POSTGRES_15"
}

variable "db_tier" {
  description = "Cloud SQL tier"
  type        = string
  default     = "db-custom-4-15360"
}

variable "db_disk_size" {
  description = "Database disk size in GB"
  type        = number
  default     = 100
}

variable "db_disk_type" {
  description = "Database disk type"
  type        = string
  default     = "PD_SSD"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "openclaw"
}

variable "db_user" {
  description = "Database username"
  type        = string
  default     = "openclaw"
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = null
  sensitive   = true
}

variable "db_high_availability" {
  description = "Enable high availability"
  type        = bool
  default     = false
}

variable "db_backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "db_backup_start_time" {
  description = "Backup start time (HH:MM)"
  type        = string
  default     = "03:00"
}

variable "db_point_in_time_recovery" {
  description = "Enable point-in-time recovery"
  type        = bool
  default     = false
}

variable "db_query_insights_enabled" {
  description = "Enable Query Insights"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Memorystore Redis Configuration
# ------------------------------------------------------------------------------

variable "redis_tier" {
  description = "Memorystore tier (BASIC, STANDARD_HA)"
  type        = string
  default     = "STANDARD_HA"
}

variable "redis_memory_size_gb" {
  description = "Redis memory size in GB"
  type        = number
  default     = 4
}

variable "redis_version" {
  description = "Redis version"
  type        = string
  default     = "REDIS_7_0"
}

variable "redis_replica_count" {
  description = "Number of read replicas"
  type        = number
  default     = 0
}

variable "redis_read_replicas_enabled" {
  description = "Enable read replicas"
  type        = bool
  default     = false
}

variable "redis_auth_enabled" {
  description = "Enable Redis AUTH"
  type        = bool
  default     = true
}

variable "redis_auth_string" {
  description = "Redis AUTH string"
  type        = string
  default     = null
  sensitive   = true
}

variable "redis_transit_encryption_enabled" {
  description = "Enable transit encryption"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Artifact Registry Configuration
# ------------------------------------------------------------------------------

variable "artifact_cleanup_policy_days" {
  description = "Days to retain images in Artifact Registry"
  type        = number
  default     = 30
}

# ------------------------------------------------------------------------------
# Load Balancer Configuration
# ------------------------------------------------------------------------------

variable "ssl_certificate_arn" {
  description = "SSL certificate manager certificate"
  type        = string
  default     = null
}

variable "managed_domain" {
  description = "Domain for managed SSL certificate"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# Monitoring Configuration
# ------------------------------------------------------------------------------

variable "enable_monitoring_alerts" {
  description = "Enable monitoring alerts"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email for alert notifications"
  type        = string
  default     = null
}
