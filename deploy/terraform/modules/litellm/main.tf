# ==============================================================================
# Heretek OpenClaw - LiteLLM Terraform Module
# ==============================================================================
# Reusable module for LiteLLM proxy deployment
# ==============================================================================

# ------------------------------------------------------------------------------
# Module Variables
# ------------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "image" {
  description = "LiteLLM container image"
  type = object({
    repository = string
    tag        = string
    pull_policy = optional(string, "IfNotPresent")
  })
  default = {
    repository = "ghcr.io/berriai/litellm"
    tag        = "main-latest"
  }
}

variable "replicas" {
  description = "Number of replicas"
  type        = number
  default     = 1
}

variable "port" {
  description = "Service port"
  type        = number
  default     = 4000
}

variable "resources" {
  description = "Container resources"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "1000m"
      memory = "2Gi"
    }
    limits = {
      cpu    = "2000m"
      memory = "4Gi"
    }
  }
}

variable "database" {
  description = "Database configuration for LiteLLM"
  type = object({
    host     = string
    port     = number
    name     = string
    username = string
    password = string
    ssl_mode = optional(string, "require")
  })
}

variable "redis" {
  description = "Redis configuration for LiteLLM"
  type = object({
    host     = string
    port     = number
    password = optional(string)
    db       = optional(number, 0)
  })
  default = {
    host = "localhost"
    port = 6379
  }
}

variable "config" {
  description = "LiteLLM configuration"
  type = object({
    master_key        = optional(string)
    master_key_secret = optional(string)
    cost_tracking     = optional(bool, true)
    metrics_enabled   = optional(bool, true)
    log_level         = optional(string, "INFO")
    ui_enabled        = optional(bool, true)
    spend_tracking    = optional(bool, true)
  })
  default = {
    cost_tracking   = true
    metrics_enabled = true
    log_level       = "INFO"
    ui_enabled      = true
  }
}

variable "providers" {
  description = "LLM provider configurations"
  type = list(object({
    name       = string
    provider   = string
    api_key    = optional(string)
    api_base   = optional(string)
    models     = list(object({
      model_name = string
      litellm_model = string
    }))
  }))
  default = []
}

variable "autoscaling" {
  description = "Autoscaling configuration"
  type = object({
    enabled              = optional(bool, false)
    min_replicas         = optional(number, 1)
    max_replicas         = optional(number, 10)
    target_cpu_percent   = optional(number, 80)
    target_memory_percent = optional(number, 80)
  })
  default = {
    enabled = false
  }
}

variable "ingress" {
  description = "Ingress configuration"
  type = object({
    enabled      = optional(bool, false)
    class_name   = optional(string, "nginx")
    hosts        = optional(list(string), [])
    tls          = optional(list(object({
      secret_name = string
      hosts       = list(string)
    })), [])
    annotations  = optional(map(string), {})
  })
  default = {
    enabled = false
  }
}

variable "monitoring" {
  description = "Monitoring configuration"
  type = object({
    enabled          = optional(bool, true)
    service_monitor  = optional(bool, false)
    prometheus_rules = optional(bool, false)
  })
  default = {
    enabled = true
  }
}

variable "security" {
  description = "Security configuration"
  type = object({
    pod_security_context = optional(object({
      run_as_non_root = optional(bool, true)
      run_as_user     = optional(number, 1000)
      fs_group        = optional(number, 1000)
    }))
    container_security_context = optional(object({
      allow_privilege_escalation = optional(bool, false)
      read_only_root_filesystem  = optional(bool, true)
      capabilities = optional(object({
        drop = optional(list(string), ["ALL"])
      }))
    }))
  })
  default = {
    pod_security_context = {
      run_as_non_root = true
      run_as_user     = 1000
    }
    container_security_context = {
      allow_privilege_escalation = false
      read_only_root_filesystem  = true
    }
  }
}

# ------------------------------------------------------------------------------
# Local Values
# ------------------------------------------------------------------------------

locals {
  common_labels = merge(var.tags, {
    "app.kubernetes.io/name"       = "litellm"
    "app.kubernetes.io/component"  = "proxy"
    "app.kubernetes.io/part-of"    = "openclaw"
    "app.kubernetes.io/managed-by" = "terraform"
  })
  
  database_url = "postgresql://${var.database.username}:${var.database.password}@${var.database.host}:${var.database.port}/${var.database.name}"
  
  redis_url = var.redis.password != null ? "redis://:${var.redis.password}@${var.redis.host}:${var.redis.port}/${var.redis.db}" : "redis://${var.redis.host}:${var.redis.port}/${var.redis.db}"
}

# ------------------------------------------------------------------------------
# Kubernetes Resources (when used with Kubernetes provider)
# ------------------------------------------------------------------------------

# Deployment
resource "kubernetes_deployment" "litellm" {
  count = var.environment == "module" ? 1 : 0  # Only when used with Kubernetes provider

  metadata {
    name      = "${var.name}-litellm"
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "litellm"
      }
    }

    template {
      metadata {
        labels = merge(local.common_labels, {
          "app.kubernetes.io/name" = "litellm"
        })
      }

      spec {
        container {
          name  = "litellm"
          image = "${var.image.repository}:${var.image.tag}"
          ports {
            container_port = var.port
          }

          env {
            name  = "DATABASE_URL"
            value = local.database_url
          }

          env {
            name  = "REDIS_URL"
            value = local.redis_url
          }

          env {
            name  = "LITELLM_MASTER_KEY"
            value = var.config.master_key
          }

          env {
            name  = "LITELLM_LOG_LEVEL"
            value = var.config.log_level
          }

          env {
            name  = "PROXY_COST_TRACKING"
            value = var.config.cost_tracking ? "True" : "False"
          }

          resources {
            requests = var.resources.requests
            limits   = var.resources.limits
          }
        }

        dynamic "security_context" {
          for_each = var.security.pod_security_context != null ? [1] : []
          content {
            run_as_non_root = var.security.pod_security_context.run_as_non_root
            run_as_user     = var.security.pod_security_context.run_as_user
            fs_group        = var.security.pod_security_context.fs_group
          }
        }
      }
    }
  }
}

# Service
resource "kubernetes_service" "litellm" {
  count = var.environment == "module" ? 1 : 0

  metadata {
    name      = "${var.name}-litellm"
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "litellm"
    }

    port {
      port        = var.port
      target_port = var.port
    }

    type = "ClusterIP"
  }
}

# ConfigMap for LiteLLM configuration
resource "kubernetes_config_map" "litellm" {
  count = var.environment == "module" ? 1 : 0

  metadata {
    name      = "${var.name}-litellm-config"
    namespace = var.namespace
    labels    = local.common_labels
  }

  data = {
    "config.yaml" = yamlencode({
      model_list = [
        for provider in var.providers : [
          for model in provider.models : {
            model_name = model.model_name
            litellm_params = {
              model      = "${provider.provider}/${model.litellm_model}"
              api_key    = provider.api_key
              api_base   = provider.api_base
            }
          }
        ]
      ]
      litellm_settings = {
        set_verbose        = var.environment == "dev"
        drop_params        = true
        max_tokens         = 4096
        request_timeout    = 600
        num_retries        = 2
      }
    })
  }
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------

output "name" {
  description = "LiteLLM deployment name"
  value       = "${var.name}-litellm"
}

output "image" {
  description = "LiteLLM container image"
  value       = "${var.image.repository}:${var.image.tag}"
}

output "port" {
  description = "LiteLLM service port"
  value       = var.port
}

output "replicas" {
  description = "Number of replicas"
  value       = var.replicas
}

output "database_url" {
  description = "Database connection URL"
  value       = local.database_url
  sensitive   = true
}

output "redis_url" {
  description = "Redis connection URL"
  value       = local.redis_url
  sensitive   = true
}

output "autoscaling_enabled" {
  description = "Whether autoscaling is enabled"
  value       = var.autoscaling.enabled
}

output "ingress_enabled" {
  description = "Whether ingress is enabled"
  value       = var.ingress.enabled
}

output "monitoring_enabled" {
  description = "Whether monitoring is enabled"
  value       = var.monitoring.enabled
}

output "common_labels" {
  description = "Common labels applied to resources"
  value       = local.common_labels
}
