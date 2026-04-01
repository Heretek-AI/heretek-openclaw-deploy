# ==============================================================================
# Heretek OpenClaw - Common Module Variables
# ==============================================================================
# Variable definitions for the OpenClaw module
# ==============================================================================

# ------------------------------------------------------------------------------
# General Configuration
# ------------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for all resources"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.name))
    error_message = "Name must be 3-20 characters, start with a letter, and contain only lowercase alphanumeric characters and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "region" {
  description = "Cloud provider region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# Application Configuration
# ------------------------------------------------------------------------------

variable "app_version" {
  description = "Application version to deploy"
  type        = string
  default     = "2026.3.28"
}

variable "gateway" {
  description = "OpenClaw Gateway configuration"
  type = object({
    image = object({
      repository = string
      tag        = string
      pull_policy = optional(string, "IfNotPresent")
    })
    replicas       = optional(number, 1)
    port           = optional(number, 18789)
    service_type   = optional(string, "ClusterIP")
    resources      = optional(object({
      requests = object({
        cpu    = optional(string, "2000m")
        memory = optional(string, "4Gi")
      })
      limits = object({
        cpu    = optional(string, "4000m")
        memory = optional(string, "8Gi")
      })
    }))
    autoscaling = optional(object({
      enabled              = optional(bool, false)
      min_replicas         = optional(number, 1)
      max_replicas         = optional(number, 5)
      target_cpu_percent   = optional(number, 80)
      target_memory_percent = optional(number, 80)
    }))
    ingress = optional(object({
      enabled      = optional(bool, false)
      class_name   = optional(string, "nginx")
      hosts        = optional(list(string), [])
      tls          = optional(list(object({
        secret_name = string
        hosts       = list(string)
      })), [])
    }))
  })
  default = {
    image = {
      repository = "heretek/openclaw-gateway"
      tag        = "2026.3.28"
    }
    replicas = 1
    port     = 18789
  }
}

variable "litellm" {
  description = "LiteLLM proxy configuration"
  type = object({
    enabled = optional(bool, true)
    image = object({
      repository = optional(string, "ghcr.io/berriai/litellm")
      tag        = optional(string, "main-latest")
    })
    replicas       = optional(number, 1)
    port           = optional(number, 4000)
    service_type   = optional(string, "ClusterIP")
    resources      = optional(object({
      requests = object({
        cpu    = optional(string, "1000m")
        memory = optional(string, "2Gi")
      })
      limits = object({
        cpu    = optional(string, "2000m")
        memory = optional(string, "4Gi")
      })
    }))
    config = optional(object({
      master_key        = optional(string)
      cost_tracking     = optional(bool, true)
      metrics_enabled   = optional(bool, true)
      log_level         = optional(string, "INFO")
    }))
  })
  default = {
    enabled = true
    image = {
      repository = "ghcr.io/berriai/litellm"
      tag        = "main-latest"
    }
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
    type             = optional(string, "managed")  # managed, self-hosted
    host             = optional(string)
    port             = optional(number, 5432)
    name             = optional(string, "openclaw")
    username         = optional(string, "openclaw")
    password         = optional(string)
    password_secret  = optional(string)
    ssl_mode         = optional(string, "require")
    pool_size        = optional(number, 10)
    max_connections  = optional(number, 100)
    pgvector_enabled = optional(bool, true)
  })
  default = {
    type = "managed"
  }
}

# ------------------------------------------------------------------------------
# Redis Configuration
# ------------------------------------------------------------------------------

variable "redis" {
  description = "Redis configuration"
  type = object({
    type             = optional(string, "managed")  # managed, self-hosted
    host             = optional(string)
    port             = optional(number, 6379)
    password         = optional(string)
    password_secret  = optional(string)
    ssl_enabled      = optional(bool, true)
    db               = optional(number, 0)
    pool_size        = optional(number, 10)
  })
  default = {
    type = "managed"
  }
}

# ------------------------------------------------------------------------------
# Ollama Configuration
# ------------------------------------------------------------------------------

variable "ollama" {
  description = "Ollama local LLM configuration"
  type = object({
    enabled = optional(bool, false)
    image = object({
      repository = optional(string, "ollama/ollama")
      tag        = optional(string, "rocm")  # rocm for AMD, latest for CPU
    })
    gpu = object({
      enabled = optional(bool, false)
      type    = optional(string, "amd")  # amd or nvidia
      device  = optional(string)
    })
    models = optional(list(string), ["nomic-embed-text-v2-moe"])
    persistence = object({
      enabled = optional(bool, true)
      size    = optional(string, "100Gi")
      storage_class = optional(string)
    })
    resources = optional(object({
      requests = object({
        cpu    = optional(string, "4000m")
        memory = optional(string, "8Gi")
      })
      limits = object({
        cpu    = optional(string, "8000m")
        memory = optional(string, "16Gi")
        gpu    = optional(string)
      })
    }))
  })
  default = {
    enabled = false
  }
}

# ------------------------------------------------------------------------------
# Neo4j Configuration
# ------------------------------------------------------------------------------

variable "neo4j" {
  description = "Neo4j GraphRAG configuration"
  type = object({
    enabled = optional(bool, true)
    image = object({
      repository = optional(string, "neo4j")
      tag        = optional(string, "5.15")
    })
    auth = object({
      username = optional(string, "neo4j")
      password = optional(string)
      password_secret = optional(string)
    })
    persistence = object({
      enabled = optional(bool, true)
      size    = optional(string, "20Gi")
      storage_class = optional(string)
    })
    resources = optional(object({
      requests = object({
        cpu    = optional(string, "2000m")
        memory = optional(string, "4Gi")
      })
      limits = object({
        cpu    = optional(string, "4000m")
        memory = optional(string, "8Gi")
      })
    }))
  })
  default = {
    enabled = true
  }
}

# ------------------------------------------------------------------------------
# Langfuse Configuration
# ------------------------------------------------------------------------------

variable "langfuse" {
  description = "Langfuse observability configuration"
  type = object({
    enabled = optional(bool, true)
    image = object({
      repository = optional(string, "langfuse/langfuse")
      tag        = optional(string, "latest")
    })
    replicas = optional(number, 1)
    ingress = optional(object({
      enabled = optional(bool, false)
      hosts   = optional(list(string), [])
    }))
    auth = optional(object({
      salt              = optional(string)
      nextauth_secret   = optional(string)
      sign_up_enabled   = optional(bool, true)
    }))
  })
  default = {
    enabled = true
  }
}

# ------------------------------------------------------------------------------
# Secrets Configuration
# ------------------------------------------------------------------------------

variable "secrets" {
  description = "API keys and secrets"
  type = object({
    minimax_api_key      = optional(string)
    zai_api_key          = optional(string)
    anthropic_api_key    = optional(string)
    openai_api_key       = optional(string)
    google_api_key       = optional(string)
    azure_openai_api_key = optional(string)
    azure_openai_endpoint = optional(string)
    langfuse_public_key  = optional(string)
    langfuse_secret_key  = optional(string)
  })
  default = {}
}

variable "external_secrets" {
  description = "External secrets manager configuration"
  type = object({
    enabled = optional(bool, false)
    store   = optional(string, "vault")  # vault, aws, gcp, azure
    refresh_interval = optional(string, "1h")
  })
  default = {
    enabled = false
  }
}

# ------------------------------------------------------------------------------
# Network Configuration
# ------------------------------------------------------------------------------

variable "network" {
  description = "Network configuration"
  type = object({
    vpc_id              = string
    subnet_ids          = list(string)
    security_group_ids  = optional(list(string))
    pod_cidr            = optional(string, "10.244.0.0/16")
    service_cidr        = optional(string, "10.96.0.0/12")
    network_policy      = optional(string, "calico")
  })
}

variable "domain" {
  description = "Domain configuration"
  type = object({
    enabled     = optional(bool, false)
    base_domain = optional(string)
    gateway_host = optional(string, "gateway")
    litellm_host = optional(string, "litellm")
    langfuse_host = optional(string, "langfuse")
    tls_secret  = optional(string)
  })
  default = {
    enabled = false
  }
}

# ------------------------------------------------------------------------------
# Monitoring Configuration
# ------------------------------------------------------------------------------

variable "monitoring" {
  description = "Monitoring and observability configuration"
  type = object({
    enabled           = optional(bool, true)
    metrics_enabled   = optional(bool, true)
    logging_enabled   = optional(bool, true)
    tracing_enabled   = optional(bool, false)
    service_monitor   = optional(object({
      enabled       = optional(bool, false)
      interval      = optional(string, "30s")
      scrape_timeout = optional(string, "10s")
    }))
    prometheus_rule   = optional(object({
      enabled = optional(bool, false)
      rules   = optional(list(any), [])
    }))
  })
  default = {
    enabled = true
  }
}

# ------------------------------------------------------------------------------
# Security Configuration
# ------------------------------------------------------------------------------

variable "security" {
  description = "Security configuration"
  type = object({
    pod_security_policy = optional(object({
      enabled = optional(bool, true)
      run_as_non_root = optional(bool, true)
      run_as_user     = optional(number, 1000)
      fs_group        = optional(number, 1000)
    }))
    network_policy = optional(object({
      enabled = optional(bool, true)
      default_policy = optional(string, "Deny")
      allowed_namespaces = optional(list(string), [])
    }))
    secrets_encryption = optional(object({
      enabled = optional(bool, false)
      kms_key_id = optional(string)
    }))
  })
  default = {
    pod_security_policy = {
      enabled = true
    }
    network_policy = {
      enabled = true
    }
  }
}

# ------------------------------------------------------------------------------
# Backup Configuration
# ------------------------------------------------------------------------------

variable "backup" {
  description = "Backup configuration"
  type = object({
    enabled = optional(bool, true)
    schedule = optional(string, "0 2 * * *")  # Daily at 2 AM
    retention_days = optional(number, 7)
    storage_location = optional(string)
  })
  default = {
    enabled = true
  }
}
