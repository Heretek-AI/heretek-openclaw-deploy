# ==============================================================================
# Heretek OpenClaw - AWS Terraform Configuration
# ==============================================================================
# Main configuration file for AWS infrastructure
# ==============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  backend "s3" {
    # Configure backend with variables or environment
    # bucket         = "terraform-state-bucket"
    # key            = "openclaw/terraform.tfstate"
    # region         = "us-east-1"
    # encrypt        = true
    # dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "openclaw"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}

provider "kubernetes" {
  host                   = aws_eks_cluster.openclaw_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.openclaw_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.openclaw_cluster.token
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.openclaw_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.openclaw_cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.openclaw_cluster.token
  }
}

# ==============================================================================
# Data Sources
# ==============================================================================

data "aws_eks_cluster_auth" "openclaw_cluster" {
  name = aws_eks_cluster.openclaw_cluster.name
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# ==============================================================================
# Local Values
# ==============================================================================

locals {
  name_prefix = "openclaw-${var.environment}"
  
  common_tags = {
    Project     = "openclaw"
    Environment = var.environment
    Version     = var.app_version
    ManagedBy   = "terraform"
  }

  gpu_instance_types = var.enable_gpu_support ? var.gpu_instance_types : []
  
  # ECR repository URLs
  ecr_repository_urls = {
    gateway  = aws_ecr_repository.openclaw_gateway.repository_url
    litellm  = aws_ecr_repository.litellm_proxy.repository_url
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
# VPC Module
# ==============================================================================

module "vpc" {
  source = "./vpc"

  vpc_cidr              = var.vpc_cidr
  aws_region            = var.aws_region
  availability_zones    = slice(data.aws_availability_zones.available.names, 0, 3)
  name_prefix           = local.name_prefix
  enable_nat_gateway    = var.enable_nat_gateway
  single_nat_gateway    = var.single_nat_gateway
  enable_flow_logs      = var.enable_vpc_flow_logs
  flow_logs_retention   = var.flow_logs_retention_days
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs

  tags = local.common_tags
}

# ==============================================================================
# EKS Cluster
# ==============================================================================

module "eks" {
  source = "./eks"

  cluster_name    = "${local.name_prefix}-eks"
  cluster_version = var.eks_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  
  # Control plane configuration
  enable_irsa              = var.enable_irsa
  enable_cluster_autoscaler = var.enable_cluster_autoscaler
  
  # Node group configuration
  node_groups           = var.node_groups
  gpu_node_groups       = local.gpu_instance_types
  gpu_enabled           = var.enable_gpu_support
  
  # Addons
  enable_aws_load_balancer_controller = true
  enable_metrics_server              = true
  enable_cluster_autoscaler_addon    = var.enable_cluster_autoscaler

  tags = local.common_tags
}

# ==============================================================================
# RDS PostgreSQL
# ==============================================================================

module "rds" {
  source = "./rds"

  identifier_prefix    = "${local.name_prefix}-pg"
  vpc_id               = module.vpc.vpc_id
  subnet_ids           = module.vpc.database_subnet_ids
  security_group_ids   = [module.eks.node_security_group_id]
  
  # Database configuration
  engine_version       = var.postgresql_version
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  
  # Authentication
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  db_password_kms_key_id = var.db_password_kms_key_id
  
  # High availability
  multi_az             = var.db_multi_az
  publicly_accessible  = false
  
  # Backup and maintenance
  backup_retention_period = var.db_backup_retention_period
  backup_window          = var.db_backup_window
  maintenance_window     = var.db_maintenance_window
  
  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]
  performance_insights_enabled    = var.db_performance_insights_enabled
  performance_insights_retention_period = var.db_performance_insights_retention

  tags = local.common_tags
}

# ==============================================================================
# ElastiCache Redis
# ==============================================================================

module "elasticache" {
  source = "./elasticache"

  cache_cluster_id   = "${local.name_prefix}-redis"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.eks.node_security_group_id]
  
  # Redis configuration
  node_type          = var.redis_node_type
  engine_version     = var.redis_engine_version
  num_cache_nodes    = var.redis_num_cache_nodes
  parameter_group_name = var.redis_parameter_group_name
  
  # High availability
  automatic_failover_enabled = var.redis_automatic_failover_enabled
  multi_az_enabled          = var.redis_multi_az_enabled
  
  # Security
  auth_token               = var.redis_auth_token
  auth_token_kms_key_id    = var.redis_auth_token_kms_key_id
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  tags = local.common_tags
}

# ==============================================================================
# ECR Repositories
# ==============================================================================

module "ecr" {
  source = "./ecr"

  repositories = {
    openclaw_gateway = {
      name                 = "openclaw-gateway"
      image_tag_mutability = "MUTABLE"
      scan_on_push         = true
    }
    litellm_proxy = {
      name                 = "litellm-proxy"
      image_tag_mutability = "MUTABLE"
      scan_on_push         = true
    }
  }

  lifecycle_policy_enabled = true
  lifecycle_policy_days    = 30

  tags = local.common_tags
}

# ==============================================================================
# Application Load Balancer
# ==============================================================================

module "alb" {
  source = "./alb"

  alb_name           = "${local.name_prefix}-alb"
  vpc_id             = var.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [module.eks.node_security_group_id]
  
  # Listener configuration
  http_port          = 80
  https_port         = 443
  ssl_policy         = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn    = var.acm_certificate_arn
  
  # Target groups
  target_groups = [
    {
      name             = "openclaw-gateway"
      port             = 18789
      protocol         = "HTTP"
      health_check_path = "/health"
    },
    {
      name             = "litellm-proxy"
      port             = 4000
      protocol         = "HTTP"
      health_check_path = "/health"
    }
  ]

  enable_deletion_protection = var.alb_deletion_protection
  enable_http2              = true
  drop_invalid_header_fields = true

  tags = local.common_tags
}

# ==============================================================================
# CloudWatch Monitoring
# ==============================================================================

module "cloudwatch" {
  source = "./monitoring"

  name_prefix        = local.name_prefix
  eks_cluster_name   = aws_eks_cluster.openclaw_cluster.name
  rds_identifier     = module.rds.db_instance_identifier
  redis_cluster_id   = module.elasticache.redis_cluster_id
  
  # Dashboard configuration
  enable_dashboard   = true
  dashboard_name     = "${local.name_prefix}-dashboard"
  
  # Alarm configuration
  enable_alarms      = var.enable_cloudwatch_alarms
  alarm_notification_arn = var.alarm_notification_arn
  
  # Log groups
  log_retention_days = var.log_retention_days

  tags = local.common_tags
}

# ==============================================================================
# Outputs
# ==============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.openclaw_cluster.endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.openclaw_cluster.name
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.rds.db_instance_endpoint
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.elasticache.redis_endpoint
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = local.ecr_repository_urls
}
