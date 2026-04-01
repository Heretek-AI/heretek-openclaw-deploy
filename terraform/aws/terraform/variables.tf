# ==============================================================================
# Heretek OpenClaw - AWS Terraform Variables
# ==============================================================================
# Input variables for AWS infrastructure
# ==============================================================================

# ------------------------------------------------------------------------------
# General Configuration
# ------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
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

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "platform-team"
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

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway (cost optimization for dev)"
  type        = bool
  default     = false
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Retention period for VPC Flow Logs"
  type        = number
  default     = 30
}

# ------------------------------------------------------------------------------
# EKS Configuration
# ------------------------------------------------------------------------------

variable "eks_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.28"
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts"
  type        = bool
  default     = true
}

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "node_groups" {
  description = "EKS node group configurations"
  type = object({
    general = object({
      instance_types = list(string)
      min_size       = number
      max_size       = number
      desired_size   = number
      disk_size      = number
    })
    compute = object({
      instance_types = list(string)
      min_size       = number
      max_size       = number
      desired_size   = number
      disk_size      = number
    })
  })
  default = {
    general = {
      instance_types = ["m6i.xlarge", "m6i.2xlarge"]
      min_size       = 1
      max_size       = 4
      desired_size   = 2
      disk_size      = 50
    }
    compute = {
      instance_types = ["c6i.2xlarge", "c6i.4xlarge"]
      min_size       = 1
      max_size       = 8
      desired_size   = 2
      disk_size      = 100
    }
  }
}

variable "enable_gpu_support" {
  description = "Enable GPU node group for Ollama"
  type        = bool
  default     = false
}

variable "gpu_instance_types" {
  description = "GPU instance types for Ollama (G5 for NVIDIA)"
  type        = list(string)
  default     = ["g5.xlarge", "g5.2xlarge"]
}

# ------------------------------------------------------------------------------
# RDS PostgreSQL Configuration
# ------------------------------------------------------------------------------

variable "postgresql_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.m6i.large"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 50
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage in GB"
  type        = number
  default     = 500
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "openclaw"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "openclaw"
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  type        = string
  default     = null
  sensitive   = true
}

variable "db_password_kms_key_id" {
  description = "KMS key ID for encrypting db_password"
  type        = string
  default     = null
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "db_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "db_backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "db_maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "db_performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "db_performance_insights_retention" {
  description = "Performance Insights retention period in days"
  type        = number
  default     = 7
}

# ------------------------------------------------------------------------------
# ElastiCache Redis Configuration
# ------------------------------------------------------------------------------

variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.m6i.large"
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

variable "redis_parameter_group_name" {
  description = "Redis parameter group name"
  type        = string
  default     = "default.redis7"
}

variable "redis_automatic_failover_enabled" {
  description = "Enable automatic failover (requires cluster mode)"
  type        = bool
  default     = false
}

variable "redis_multi_az_enabled" {
  description = "Enable Multi-AZ for Redis"
  type        = bool
  default     = false
}

variable "redis_auth_token" {
  description = "Redis authentication token"
  type        = string
  default     = null
  sensitive   = true
}

variable "redis_auth_token_kms_key_id" {
  description = "KMS key ID for encrypting redis_auth_token"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# ECR Configuration
# ------------------------------------------------------------------------------

variable "lifecycle_policy_days" {
  description = "Days to retain images in ECR"
  type        = number
  default     = 30
}

# ------------------------------------------------------------------------------
# ALB Configuration
# ------------------------------------------------------------------------------

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener"
  type        = string
  default     = null
}

variable "alb_deletion_protection" {
  description = "Enable ALB deletion protection"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# CloudWatch Configuration
# ------------------------------------------------------------------------------

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "alarm_notification_arn" {
  description = "SNS topic ARN for alarm notifications"
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period"
  type        = number
  default     = 30
}
