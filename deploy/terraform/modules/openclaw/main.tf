# ==============================================================================
# Heretek OpenClaw - Common Terraform Module
# ==============================================================================
# Reusable module for OpenClaw deployment across cloud providers
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

# ------------------------------------------------------------------------------
# OpenClaw Gateway Configuration
# ------------------------------------------------------------------------------

variable "gateway" {
  description = "Gateway configuration"
  type = object({
    image          = string
    replicas       = number
    port           = number
    resources      = optional(object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    }))
    autoscaling = optional(object({
      enabled    = bool
      min_replicas = number
      max_replicas = number
      target_cpu   = number
    }))
  })
  default = {
    image    = "heretek/openclaw-gateway:latest"
    replicas = 1
    port     = 18789
  }
}

# ------------------------------------------------------------------------------
# LiteLLM Configuration
# ------------------------------------------------------------------------------

variable "litellm" {
  description = "LiteLLM configuration"
  type = object({
    image     = string
    replicas  = number
    port      = number
    resources = optional(object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    }))
  })
  default = {
    image    = "ghcr.io/berriai/litellm:main-latest"
    replicas = 1
    port     = 4000
  }
}

# ------------------------------------------------------------------------------
# Database Configuration
# ------------------------------------------------------------------------------

variable "database" {
  description = "Database configuration"
  type = object({
    type     = string  # rds, cloud_sql, azure_postgresql
    host     = string
    port     = number
    name     = string
    username = string
    password = string
    ssl_mode = optional(string, "require")
  })
}

# ------------------------------------------------------------------------------
# Redis Configuration
# ------------------------------------------------------------------------------

variable "redis" {
  description = "Redis configuration"
  type = object({
    type     = string  # elasticache, memorystore, azure_redis
    host     = string
    port     = number
    password = optional(string)
    ssl      = optional(bool, true)
  })
}

# ------------------------------------------------------------------------------
# Ollama Configuration (Optional)
# ------------------------------------------------------------------------------

variable "ollama" {
  description = "Ollama configuration for local LLM"
  type = object({
    enabled = bool
    image   = optional(string, "ollama/ollama:latest")
    gpu     = optional(bool, false)
    models  = optional(list(string), ["nomic-embed-text-v2-moe"])
    resources = optional(object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
        gpu    = optional(string)
      })
    }))
  })
  default = {
    enabled = false
  }
}

# ------------------------------------------------------------------------------
# Neo4j Configuration (Optional for GraphRAG)
# ------------------------------------------------------------------------------

variable "neo4j" {
  description = "Neo4j configuration for GraphRAG"
  type = object({
    enabled  = bool
    image    = optional(string, "neo4j:5.15")
    username = optional(string, "neo4j")
    password = optional(string)
    resources = optional(object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    }))
  })
  default = {
    enabled = false
  }
}

# ------------------------------------------------------------------------------
# Langfuse Configuration (Optional for Observability)
# ------------------------------------------------------------------------------

variable "langfuse" {
  description = "Langfuse observability configuration"
  type = object({
    enabled  = bool
    image    = optional(string, "langfuse/langfuse:latest")
    host     = optional(string)
    public_key = optional(string)
    secret_key = optional(string)
  })
  default = {
    enabled = false
  }
}

# ------------------------------------------------------------------------------
# Secrets Configuration
# ------------------------------------------------------------------------------

variable "secrets" {
  description = "Secrets configuration"
  type = object({
    minimax_api_key = optional(string)
    zai_api_key     = optional(string)
    anthropic_api_key = optional(string)
    openai_api_key  = optional(string)
    google_api_key  = optional(string)
    azure_openai_api_key = optional(string)
  })
  default = {}
}

# ------------------------------------------------------------------------------
# Networking Configuration
# ------------------------------------------------------------------------------

variable "network" {
  description = "Network configuration"
  type = object({
    vpc_id          = string
    subnet_ids      = list(string)
    security_groups = optional(list(string))
  })
}

# ------------------------------------------------------------------------------
# Monitoring Configuration
# ------------------------------------------------------------------------------

variable "monitoring" {
  description = "Monitoring configuration"
  type = object({
    enabled        = bool
    metrics_enabled = optional(bool, true)
    logging_enabled = optional(bool, true)
    tracing_enabled = optional(bool, false)
  })
  default = {
    enabled = true
  }
}

# ------------------------------------------------------------------------------
# Local Values
# ------------------------------------------------------------------------------

locals {
  common_labels = merge(var.tags, {
    "app.kubernetes.io/name"       = "openclaw"
    "app.kubernetes.io/component"  = "gateway"
    "app.kubernetes.io/part-of"    = "openclaw"
    "app.kubernetes.io/managed-by" = "terraform"
  })
  
  default_resources = {
    gateway = {
      requests = {
        cpu    = "2000m"
        memory = "4Gi"
      }
      limits = {
        cpu    = "4000m"
        memory = "8Gi"
      }
    }
    litellm = {
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
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------

output "gateway_config" {
  description = "Gateway configuration"
  value = {
    image    = var.gateway.image
    port     = var.gateway.port
    replicas = var.gateway.replicas
  }
}

output "litellm_config" {
  description = "LiteLLM configuration"
  value = {
    image    = var.litellm.image
    port     = var.litellm.port
    replicas = var.litellm.replicas
  }
}

output "database_connection_string" {
  description = "Database connection string"
  value       = "postgresql://${var.database.username}:${var.database.password}@${var.database.host}:${var.database.port}/${var.database.name}"
  sensitive   = true
}

output "redis_connection_string" {
  description = "Redis connection string"
  value       = "redis://${var.redis.password != null ? ":${var.redis.password}@" : ""}${var.redis.host}:${var.redis.port}"
  sensitive   = true
}

output "ollama_enabled" {
  description = "Whether Ollama is enabled"
  value       = var.ollama.enabled
}

output "neo4j_enabled" {
  description = "Whether Neo4j is enabled"
  value       = var.neo4j.enabled
}

output "langfuse_enabled" {
  description = "Whether Langfuse is enabled"
  value       = var.langfuse.enabled
}
