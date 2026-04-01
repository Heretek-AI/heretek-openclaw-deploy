# ==============================================================================
# Heretek OpenClaw - AWS Terraform Outputs
# ==============================================================================
# Output values for AWS infrastructure
# ==============================================================================

# ------------------------------------------------------------------------------
# VPC Outputs
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = module.vpc.database_subnet_ids
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.nat_gateway_ids
}

# ------------------------------------------------------------------------------
# EKS Outputs
# ------------------------------------------------------------------------------

output "eks_cluster_id" {
  description = "The ID of the EKS cluster"
  value       = aws_eks_cluster.openclaw_cluster.id
}

output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.openclaw_cluster.name
}

output "eks_cluster_endpoint" {
  description = "The endpoint of the EKS cluster"
  value       = aws_eks_cluster.openclaw_cluster.endpoint
  sensitive   = true
}

output "eks_cluster_certificate_authority" {
  description = "The certificate authority of the EKS cluster"
  value       = aws_eks_cluster.openclaw_cluster.certificate_authority[0].data
  sensitive   = true
}

output "eks_cluster_version" {
  description = "The Kubernetes version of the EKS cluster"
  value       = aws_eks_cluster.openclaw_cluster.version
}

output "eks_cluster_security_group_id" {
  description = "The security group ID of the EKS cluster"
  value       = aws_eks_cluster.openclaw_cluster.vpc_config[0].cluster_security_group_id
}

output "eks_node_security_group_id" {
  description = "The node security group ID"
  value       = module.eks.node_security_group_id
}

output "eks_oidc_provider_arn" {
  description = "The ARN of the OIDC provider"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "eks_kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.openclaw_cluster.name} --region ${var.aws_region}"
}

# ------------------------------------------------------------------------------
# RDS PostgreSQL Outputs
# ------------------------------------------------------------------------------

output "rds_instance_id" {
  description = "The ID of the RDS instance"
  value       = module.rds.db_instance_id
}

output "rds_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = module.rds.db_instance_arn
}

output "rds_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = module.rds.db_instance_endpoint
}

output "rds_port" {
  description = "The port of the RDS instance"
  value       = module.rds.db_instance_port
}

output "rds_database_name" {
  description = "The name of the database"
  value       = module.rds.db_name
}

output "rds_username" {
  description = "The master username of the RDS instance"
  value       = module.rds.db_username
  sensitive   = true
}

output "rds_connection_string" {
  description = "The PostgreSQL connection string"
  value       = "postgresql://${module.rds.db_username}:${var.db_password}@${module.rds.db_instance_endpoint}/${module.rds.db_name}"
  sensitive   = true
}

output "rds_security_group_id" {
  description = "The security group ID of the RDS instance"
  value       = module.rds.db_security_group_id
}

# ------------------------------------------------------------------------------
# ElastiCache Redis Outputs
# ------------------------------------------------------------------------------

output "redis_cluster_id" {
  description = "The ID of the Redis cluster"
  value       = module.elasticache.redis_cluster_id
}

output "redis_endpoint" {
  description = "The endpoint of the Redis cluster"
  value       = module.elasticache.redis_endpoint
}

output "redis_port" {
  description = "The port of the Redis cluster"
  value       = module.elasticache.redis_port
}

output "redis_connection_string" {
  description = "The Redis connection string"
  value       = "redis://${var.redis_auth_token != null ? "${var.redis_auth_token}@" : ""}${module.elasticache.redis_endpoint}:${module.elasticache.redis_port}"
  sensitive   = true
}

output "redis_security_group_id" {
  description = "The security group ID of the Redis cluster"
  value       = module.elasticache.redis_security_group_id
}

# ------------------------------------------------------------------------------
# ECR Outputs
# ------------------------------------------------------------------------------

output "ecr_repository_arns" {
  description = "ARNs of ECR repositories"
  value       = module.ecr.repository_arns
}

output "ecr_repository_urls" {
  description = "URLs of ECR repositories"
  value       = module.ecr.repository_urls
}

output "ecr_registry_id" {
  description = "ECR registry ID"
  value       = module.ecr.registry_id
}

# ------------------------------------------------------------------------------
# ALB Outputs
# ------------------------------------------------------------------------------

output "alb_id" {
  description = "The ID of the ALB"
  value       = module.alb.alb_id
}

output "alb_arn" {
  description = "The ARN of the ALB"
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "The Zone ID of the ALB"
  value       = module.alb.alb_zone_id
}

output "alb_security_group_id" {
  description = "The security group ID of the ALB"
  value       = module.alb.alb_security_group_id
}

output "alb_http_listener_arn" {
  description = "The ARN of the HTTP listener"
  value       = module.alb.http_listener_arn
}

output "alb_https_listener_arn" {
  description = "The ARN of the HTTPS listener"
  value       = module.alb.https_listener_arn
}

# ------------------------------------------------------------------------------
# CloudWatch Outputs
# ------------------------------------------------------------------------------

output "cloudwatch_dashboard_arn" {
  description = "The ARN of the CloudWatch dashboard"
  value       = module.cloudwatch.dashboard_arn
}

output "cloudwatch_log_groups" {
  description = "Map of CloudWatch log group names"
  value       = module.cloudwatch.log_group_names
}

output "cloudwatch_alarm_arns" {
  description = "List of CloudWatch alarm ARNs"
  value       = module.cloudwatch.alarm_arns
}

# ------------------------------------------------------------------------------
# Cost Estimation
# ------------------------------------------------------------------------------

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    eks_cluster         = "~$73 (control plane)"
    eks_nodes_general   = "~$${var.node_groups.general.desired_size * 140} (general nodes)"
    eks_nodes_compute   = "~$${var.node_groups.compute.desired_size * 250} (compute nodes)"
    eks_nodes_gpu       = var.enable_gpu_support ? "~$${2 * 2000} (GPU nodes)" : "$0"
    rds_postgresql      = "~$${var.db_multi_az ? 250 : 125} (db.${var.db_instance_class})"
    elasticache_redis   = "~$${var.redis_multi_az_enabled ? 150 : 75} (${var.redis_node_type})"
    nat_gateway         = var.single_nat_gateway ? "~$32" : "~$64"
    alb                 = "~$16"
    data_transfer       = "Variable"
    total_estimate      = "See AWS Cost Explorer for accurate pricing"
  }
}
