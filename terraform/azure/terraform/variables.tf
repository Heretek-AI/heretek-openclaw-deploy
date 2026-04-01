# ==============================================================================
# Heretek OpenClaw - Azure Terraform Variables
# ==============================================================================
# Input variables for Azure infrastructure
# ==============================================================================

# ------------------------------------------------------------------------------
# General Configuration
# ------------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
  default     = "openclaw-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
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
# VNet Configuration
# ------------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "VNet address space"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_configs" {
  description = "Subnet configurations"
  type = map(object({
    name          = string
    address_prefixes = list(string)
  }))
  default = {
    aks = {
      name             = "aks-subnet"
      address_prefixes = ["10.0.1.0/24"]
    }
    database = {
      name             = "database-subnet"
      address_prefixes = ["10.0.2.0/24"]
    }
    cache = {
      name             = "cache-subnet"
      address_prefixes = ["10.0.3.0/24"]
    }
    gateway = {
      name             = "gateway-subnet"
      address_prefixes = ["10.0.4.0/24"]
    }
  }
}

variable "enable_ddos_protection" {
  description = "Enable DDoS protection"
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable NSG flow logs"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# AKS Configuration
# ------------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.28"
}

variable "default_node_pool" {
  description = "Default node pool configuration"
  type = object({
    name                = string
    vm_size             = string
    node_count          = number
    min_count           = number
    max_count           = number
    enable_auto_scaling = bool
    os_disk_size_gb     = number
    type                = string
    availability_zones  = list(string)
  })
  default = {
    name                = "default"
    vm_size             = "Standard_D4s_v3"
    node_count          = 2
    min_count           = 1
    max_count           = 4
    enable_auto_scaling = true
    os_disk_size_gb     = 100
    type                = "VirtualMachineScaleSets"
    availability_zones  = ["1", "2", "3"]
  }
}

variable "system_node_pool" {
  description = "System node pool configuration"
  type = object({
    name                = string
    vm_size             = string
    node_count          = number
    min_count           = number
    max_count           = number
    enable_auto_scaling = bool
    os_disk_size_gb     = number
    availability_zones  = list(string)
  })
  default = {
    name                = "system"
    vm_size             = "Standard_D2s_v3"
    node_count          = 2
    min_count           = 1
    max_count           = 3
    enable_auto_scaling = true
    os_disk_size_gb     = 50
    availability_zones  = ["1", "2", "3"]
  }
}

variable "user_node_pools" {
  description = "User node pool configurations"
  type = list(object({
    name                = string
    vm_size             = string
    node_count          = number
    min_count           = number
    max_count           = number
    enable_auto_scaling = bool
    os_disk_size_gb     = number
    availability_zones  = list(string)
  }))
  default = [
    {
      name                = "compute"
      vm_size             = "Standard_D8s_v3"
      node_count          = 2
      min_count           = 1
      max_count           = 8
      enable_auto_scaling = true
      os_disk_size_gb     = 200
      availability_zones  = ["1", "2", "3"]
    }
  ]
}

variable "enable_gpu_support" {
  description = "Enable GPU node pool for Ollama"
  type        = bool
  default     = false
}

variable "gpu_node_pool" {
  description = "GPU node pool configuration"
  type = object({
    name                = string
    vm_size             = string
    node_count          = number
    min_count           = number
    max_count           = number
    enable_auto_scaling = bool
    os_disk_size_gb     = number
    availability_zones  = list(string)
  })
  default = {
    name                = "gpu"
    vm_size             = "Standard_NC4as_T4_v3"
    node_count          = 1
    min_count           = 0
    max_count           = 4
    enable_auto_scaling = true
    os_disk_size_gb     = 200
    availability_zones  = ["1", "2", "3"]
  }
}

variable "enable_private_cluster" {
  description = "Enable private AKS cluster"
  type        = bool
  default     = false
}

variable "enable_azure_policy" {
  description = "Enable Azure Policy addon"
  type        = bool
  default     = true
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Azure Database for PostgreSQL Configuration
# ------------------------------------------------------------------------------

variable "postgresql_sku_name" {
  description = "PostgreSQL SKU name"
  type        = string
  default     = "GP_Gen5_2"
}

variable "postgresql_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 102400
}

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"
}

variable "db_administrator_login" {
  description = "PostgreSQL administrator login"
  type        = string
  default     = "openclaw"
  sensitive   = true
}

variable "db_administrator_password" {
  description = "PostgreSQL administrator password"
  type        = string
  default     = null
  sensitive   = true
}

variable "db_geo_redundant_backup" {
  description = "Enable geo-redundant backup"
  type        = bool
  default     = false
}

variable "db_auto_grow_enabled" {
  description = "Enable storage auto-grow"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Azure Cache for Redis Configuration
# ------------------------------------------------------------------------------

variable "redis_capacity" {
  description = "Redis cache capacity"
  type        = number
  default     = 2
}

variable "redis_family" {
  description = "Redis SKU family (C, P, E)"
  type        = string
  default     = "C"
}

variable "redis_sku_name" {
  description = "Redis SKU name (Basic, Standard, Premium)"
  type        = string
  default     = "Standard"
}

variable "redis_version" {
  description = "Redis version"
  type        = string
  default     = "6"
}

variable "redis_password" {
  description = "Redis authentication password"
  type        = string
  default     = null
  sensitive   = true
}

variable "redis_zones" {
  description = "Availability zones for Redis"
  type        = list(string)
  default     = ["1", "2", "3"]
}

# ------------------------------------------------------------------------------
# Azure Container Registry Configuration
# ------------------------------------------------------------------------------

variable "acr_sku" {
  description = "ACR SKU (Basic, Standard, Premium)"
  type        = string
  default     = "Standard"
}

variable "acr_retention_policy_days" {
  description = "ACR retention policy days"
  type        = number
  default     = 30
}

# ------------------------------------------------------------------------------
# Application Gateway Configuration
# ------------------------------------------------------------------------------

variable "gateway_sku_name" {
  description = "Application Gateway SKU"
  type        = string
  default     = "Standard_v2"
}

variable "gateway_capacity" {
  description = "Application Gateway capacity"
  type        = number
  default     = 2
}

variable "ssl_certificate_key_vault_secret_id" {
  description = "Key Vault secret ID for SSL certificate"
  type        = string
  default     = null
}

variable "ssl_certificate_data" {
  description = "Base64 encoded SSL certificate data"
  type        = string
  default     = null
  sensitive   = true
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
