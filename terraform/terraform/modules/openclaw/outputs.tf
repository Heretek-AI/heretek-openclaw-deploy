# ==============================================================================
# Heretek OpenClaw - Common Module Outputs
# ==============================================================================
# Output definitions for the OpenClaw module
# ==============================================================================

# ------------------------------------------------------------------------------
# Application Outputs
# ------------------------------------------------------------------------------

output "name" {
  description = "Name prefix used for resources"
  value       = var.name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "app_version" {
  description = "Application version"
  value       = var.app_version
}

# ------------------------------------------------------------------------------
# Gateway Outputs
# ------------------------------------------------------------------------------

output "gateway_image" {
  description = "Gateway container image"
  value       = "${var.gateway.image.repository}:${var.gateway.image.tag}"
}

output "gateway_port" {
  description = "Gateway service port"
  value       = var.gateway.port
}

output "gateway_replicas" {
  description = "Gateway replica count"
  value       = var.gateway.replicas
}

output "gateway_autoscaling_enabled" {
  description = "Whether gateway autoscaling is enabled"
  value       = var.gateway.autoscaling.enabled
}

output "gateway_ingress_enabled" {
  description = "Whether gateway ingress is enabled"
  value       = var.gateway.ingress.enabled
}

# ------------------------------------------------------------------------------
# LiteLLM Outputs
# ------------------------------------------------------------------------------

output "litellm_enabled" {
  description = "Whether LiteLLM is enabled"
  value       = var.litellm.enabled
}

output "litellm_image" {
  description = "LiteLLM container image"
  value       = "${var.litellm.image.repository}:${var.litellm.image.tag}"
}

output "litellm_port" {
  description = "LiteLLM service port"
  value       = var.litellm.port
}

output "litellm_replicas" {
  description = "LiteLLM replica count"
  value       = var.litellm.replicas
}

# ------------------------------------------------------------------------------
# Database Outputs
# ------------------------------------------------------------------------------

output "database_type" {
  description = "Database type (managed or self-hosted)"
  value       = var.database.type
}

output "database_connection_string" {
  description = "Database connection string"
  value       = var.database.host != null ? "postgresql://${var.database.username}:${var.database.password}@${var.database.host}:${var.database.port}/${var.database.name}" : null
  sensitive   = true
}

output "database_pgvector_enabled" {
  description = "Whether pgvector is enabled"
  value       = var.database.pgvector_enabled
}

# ------------------------------------------------------------------------------
# Redis Outputs
# ------------------------------------------------------------------------------

output "redis_type" {
  description = "Redis type (managed or self-hosted)"
  value       = var.redis.type
}

output "redis_connection_string" {
  description = "Redis connection string"
  value       = var.redis.host != null ? "redis://${var.redis.password != null ? ":${var.redis.password}@" : ""}${var.redis.host}:${var.redis.port}" : null
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Ollama Outputs
# ------------------------------------------------------------------------------

output "ollama_enabled" {
  description = "Whether Ollama is enabled"
  value       = var.ollama.enabled
}

output "ollama_gpu_enabled" {
  description = "Whether Ollama GPU support is enabled"
  value       = var.ollama.gpu.enabled
}

output "ollama_gpu_type" {
  description = "Ollama GPU type (amd or nvidia)"
  value       = var.ollama.gpu.type
}

output "ollama_models" {
  description = "List of Ollama models to pull"
  value       = var.ollama.models
}

output "ollama_image" {
  description = "Ollama container image"
  value       = "${var.ollama.image.repository}:${var.ollama.image.tag}"
}

# ------------------------------------------------------------------------------
# Neo4j Outputs
# ------------------------------------------------------------------------------

output "neo4j_enabled" {
  description = "Whether Neo4j is enabled"
  value       = var.neo4j.enabled
}

output "neo4j_image" {
  description = "Neo4j container image"
  value       = "${var.neo4j.image.repository}:${var.neo4j.image.tag}"
}

# ------------------------------------------------------------------------------
# Langfuse Outputs
# ------------------------------------------------------------------------------

output "langfuse_enabled" {
  description = "Whether Langfuse is enabled"
  value       = var.langfuse.enabled
}

output "langfuse_image" {
  description = "Langfuse container image"
  value       = "${var.langfuse.image.repository}:${var.langfuse.image.tag}"
}

output "langfuse_ingress_enabled" {
  description = "Whether Langfuse ingress is enabled"
  value       = var.langfuse.ingress.enabled
}

# ------------------------------------------------------------------------------
# Secrets Outputs
# ------------------------------------------------------------------------------

output "secrets_configured" {
  description = "List of configured secret keys"
  value       = [for key in keys(var.secrets) : key if var.secrets[key] != null]
  sensitive   = true
}

output "external_secrets_enabled" {
  description = "Whether external secrets manager is enabled"
  value       = var.external_secrets.enabled
}

output "external_secrets_store" {
  description = "External secrets store type"
  value       = var.external_secrets.store
}

# ------------------------------------------------------------------------------
# Network Outputs
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID"
  value       = var.network.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs"
  value       = var.network.subnet_ids
}

output "pod_cidr" {
  description = "Pod CIDR range"
  value       = var.network.pod_cidr
}

output "service_cidr" {
  description = "Service CIDR range"
  value       = var.network.service_cidr
}

output "network_policy" {
  description = "Network policy provider"
  value       = var.network.network_policy
}

# ------------------------------------------------------------------------------
# Domain Outputs
# ------------------------------------------------------------------------------

output "domain_enabled" {
  description = "Whether custom domain is enabled"
  value       = var.domain.enabled
}

output "domain_base" {
  description = "Base domain name"
  value       = var.domain.base_domain
}

output "domain_hosts" {
  description = "Configured domain hosts"
  value = var.domain.enabled ? {
    gateway  = "${var.domain.gateway_host}.${var.domain.base_domain}"
    litellm  = "${var.domain.litellm_host}.${var.domain.base_domain}"
    langfuse = "${var.domain.langfuse_host}.${var.domain.base_domain}"
  } : {}
}

# ------------------------------------------------------------------------------
# Monitoring Outputs
# ------------------------------------------------------------------------------

output "monitoring_enabled" {
  description = "Whether monitoring is enabled"
  value       = var.monitoring.enabled
}

output "metrics_enabled" {
  description = "Whether metrics collection is enabled"
  value       = var.monitoring.metrics_enabled
}

output "logging_enabled" {
  description = "Whether logging is enabled"
  value       = var.monitoring.logging_enabled
}

output "tracing_enabled" {
  description = "Whether distributed tracing is enabled"
  value       = var.monitoring.tracing_enabled
}

output "service_monitor_enabled" {
  description = "Whether Prometheus ServiceMonitor is enabled"
  value       = var.monitoring.service_monitor.enabled
}

# ------------------------------------------------------------------------------
# Security Outputs
# ------------------------------------------------------------------------------

output "pod_security_enabled" {
  description = "Whether pod security policy is enabled"
  value       = var.security.pod_security_policy.enabled
}

output "network_policy_enabled" {
  description = "Whether network policy is enabled"
  value       = var.security.network_policy.enabled
}

output "secrets_encryption_enabled" {
  description = "Whether secrets encryption is enabled"
  value       = var.security.secrets_encryption.enabled
}

# ------------------------------------------------------------------------------
# Backup Outputs
# ------------------------------------------------------------------------------

output "backup_enabled" {
  description = "Whether automated backups are enabled"
  value       = var.backup.enabled
}

output "backup_schedule" {
  description = "Backup schedule (cron expression)"
  value       = var.backup.schedule
}

output "backup_retention_days" {
  description = "Backup retention period in days"
  value       = var.backup.retention_days
}

# ------------------------------------------------------------------------------
# Resource Labels
# ------------------------------------------------------------------------------

output "common_labels" {
  description = "Common labels applied to all resources"
  value = {
    "app.kubernetes.io/name"       = "openclaw"
    "app.kubernetes.io/component"  = "gateway"
    "app.kubernetes.io/part-of"    = "openclaw"
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/version"    = var.app_version
    "environment"                  = var.environment
  }
}

# ------------------------------------------------------------------------------
# Configuration Summary
# ------------------------------------------------------------------------------

output "configuration_summary" {
  description = "Summary of the OpenClaw configuration"
  value = {
    name         = var.name
    environment  = var.environment
    version      = var.app_version
    
    components = {
      gateway  = true
      litellm  = var.litellm.enabled
      ollama   = var.ollama.enabled
      neo4j    = var.neo4j.enabled
      langfuse = var.langfuse.enabled
    }
    
    database = {
      type      = var.database.type
      pgvector  = var.database.pgvector_enabled
    }
    
    redis = {
      type = var.redis.type
    }
    
    monitoring = {
      enabled  = var.monitoring.enabled
      metrics  = var.monitoring.metrics_enabled
      logging  = var.monitoring.logging_enabled
      tracing  = var.monitoring.tracing_enabled
    }
    
    security = {
      pod_security    = var.security.pod_security_policy.enabled
      network_policy  = var.security.network_policy.enabled
      secrets_encryption = var.security.secrets_encryption.enabled
    }
    
    backup = {
      enabled   = var.backup.enabled
      schedule  = var.backup.schedule
      retention = var.backup.retention_days
    }
  }
}
