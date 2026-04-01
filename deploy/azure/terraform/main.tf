# ==============================================================================
# Heretek OpenClaw - Azure Terraform Configuration
# ==============================================================================
# Main configuration file for Azure infrastructure
# ==============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
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

  backend "azurerm" {
    # Configure backend with variables or environment
    # resource_group_name  = "terraform-state-rg"
    # storage_account_name = "tfstatestorage"
    # container_name       = "tfstate"
    # key                  = "openclaw/terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.openclaw_cluster.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.openclaw_cluster.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.openclaw_cluster.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.openclaw_cluster.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.openclaw_cluster.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.openclaw_cluster.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.openclaw_cluster.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.openclaw_cluster.kube_config[0].cluster_ca_certificate)
  }
}

# ==============================================================================
# Data Sources
# ==============================================================================

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
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
  
  # ACR URLs
  acr_urls = {
    login_server = azurerm_container_registry.openclaw.login_server
    gateway      = "${azurerm_container_registry.openclaw.login_server}/openclaw-gateway"
    litellm      = "${azurerm_container_registry.openclaw.login_server}/litellm-proxy"
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
# Resource Group
# ==============================================================================

resource "azurerm_resource_group" "openclaw" {
  name     = var.resource_group_name
  location = var.location

  tags = local.common_tags
}

# ==============================================================================
# VNet
# ==============================================================================

module "vnet" {
  source = "./vnet"

  resource_group_name = azurerm_resource_group.openclaw.name
  location            = var.location
  vnet_name           = "${local.name_prefix}-vnet"
  vnet_address_space  = var.vnet_address_space
  subnet_configs      = var.subnet_configs
  enable_ddos_protection = var.enable_ddos_protection
  enable_flow_logs    = var.enable_flow_logs

  tags = local.common_tags
}

# ==============================================================================
# AKS Cluster
# ==============================================================================

module "aks" {
  source = "./aks"

  resource_group_name     = azurerm_resource_group.openclaw.name
  location                = var.location
  cluster_name            = "${local.name_prefix}-aks"
  vnet_id                 = module.vnet.vnet_id
  subnet_id               = module.vnet.aks_subnet_id
  
  # AKS configuration
  kubernetes_version      = var.kubernetes_version
  dns_prefix              = local.name_prefix
  
  # Node pool configuration
  default_node_pool       = var.default_node_pool
  system_node_pool        = var.system_node_pool
  user_node_pools         = var.user_node_pools
  gpu_node_pool           = var.gpu_node_pool
  gpu_enabled             = local.gpu_enabled
  
  # Security
  enable_private_cluster  = var.enable_private_cluster
  enable_azure_policy     = var.enable_azure_policy
  enable_workload_identity = var.enable_workload_identity
  
  # Monitoring
  enable_monitoring       = true
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  tags = local.common_tags
}

# ==============================================================================
# Azure Database for PostgreSQL
# ==============================================================================

module "postgresql" {
  source = "./postgresql"

  resource_group_name     = azurerm_resource_group.openclaw.name
  location                = var.location
  server_name             = "${local.name_prefix}-pg"
  vnet_id                 = module.vnet.vnet_id
  subnet_id               = module.vnet.database_subnet_id
  
  # Database configuration
  sku_name                = var.postgresql_sku_name
  storage_mb              = var.postgresql_storage_mb
  version                 = var.postgresql_version
  
  # Authentication
  administrator_login     = var.db_administrator_login
  administrator_password  = var.db_administrator_password
  
  # High availability
  geo_redundant_backup    = var.db_geo_redundant_backup
  auto_grow_enabled       = var.db_auto_grow_enabled
  
  # Security
  ssl_enforcement_enabled = true
  ssl_minimal_tls_version_enforced = "TLS1_2"
  public_network_access_enabled = false

  tags = local.common_tags
}

# ==============================================================================
# Azure Cache for Redis
# ==============================================================================

module "redis" {
  source = "./redis"

  resource_group_name     = azurerm_resource_group.openclaw.name
  location                = var.location
  cache_name              = "${local.name_prefix}-redis"
  vnet_id                 = module.vnet.vnet_id
  subnet_id               = module.vnet.cache_subnet_id
  
  # Redis configuration
  capacity                = var.redis_capacity
  family                  = var.redis_family
  sku_name                = var.redis_sku_name
  redis_version           = var.redis_version
  
  # Security
  enable_non_ssl_port     = false
  minimum_tls_version     = "1.2"
  
  # High availability
  zones                   = var.redis_zones

  tags = local.common_tags
}

# ==============================================================================
# Azure Container Registry
# ==============================================================================

module "acr" {
  source = "./acr"

  resource_group_name     = azurerm_resource_group.openclaw.name
  location                = var.location
  registry_name           = "${local.name_prefix}acr"
  sku                     = var.acr_sku
  
  # Cleanup
  retention_policy_days   = var.acr_retention_policy_days
  quarantine_policy_enabled = var.environment == "prod"

  tags = local.common_tags
}

# ==============================================================================
# Application Gateway
# ==============================================================================

module "application_gateway" {
  source = "./application-gateway"

  resource_group_name     = azurerm_resource_group.openclaw.name
  location                = var.location
  gateway_name            = "${local.name_prefix}-agw"
  vnet_id                 = module.vnet.vnet_id
  subnet_id               = module.vnet.gateway_subnet_id
  
  # Gateway configuration
  sku_name                = var.gateway_sku_name
  capacity                = var.gateway_capacity
  
  # SSL
  ssl_certificate_key_vault_secret_id = var.ssl_certificate_key_vault_secret_id
  ssl_certificate_data                = var.ssl_certificate_data
  
  # Backend pools
  backend_pools = [
    {
      name        = "openclaw-gateway"
      port        = 18789
      probe_path  = "/health"
    },
    {
      name        = "litellm-proxy"
      port        = 4000
      probe_path  = "/health"
    }
  ]

  tags = local.common_tags
}

# ==============================================================================
# Monitoring
# ==============================================================================

module "monitoring" {
  source = "../terraform/modules/monitoring"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.openclaw.name
  location            = var.location
  aks_cluster_id      = azurerm_kubernetes_cluster.openclaw_cluster.id
  postgresql_server_id = module.postgresql.server_id
  redis_cache_id      = module.redis.redis_cache_id
  
  # Dashboard
  enable_dashboard    = true
  
  # Alerts
  enable_alerts       = var.enable_monitoring_alerts
  alert_email         = var.alert_email

  tags = local.common_tags
}

# ==============================================================================
# Key Vault (for secrets)
# ==============================================================================

resource "azurerm_key_vault" "openclaw" {
  name                = "${local.name_prefix}-kv"
  location            = var.location
  resource_group_name = azurerm_resource_group.openclaw.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  purge_protection_enabled = var.environment == "prod"

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.db_administrator_password
  key_vault_id = azurerm_key_vault.openclaw.id
}

resource "azurerm_key_vault_secret" "redis_password" {
  name         = "redis-password"
  value        = var.redis_password
  key_vault_id = azurerm_key_vault.openclaw.id
}

# ==============================================================================
# Outputs
# ==============================================================================

output "vnet_id" {
  description = "VNet ID"
  value       = module.vnet.vnet_id
}

output "aks_cluster_id" {
  description = "AKS cluster ID"
  value       = azurerm_kubernetes_cluster.openclaw_cluster.id
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.openclaw_cluster.name
}

output "aks_fqdn" {
  description = "AKS cluster FQDN"
  value       = azurerm_kubernetes_cluster.openclaw_cluster.fqdn
}

output "postgresql_fqdn" {
  description = "PostgreSQL server FQDN"
  value       = module.postgresql.fqdn
}

output "redis_hostname" {
  description = "Redis cache hostname"
  value       = module.redis.hostname
}

output "acr_login_server" {
  description = "ACR login server"
  value       = module.acr.login_server
}

output "application_gateway_public_ip" {
  description = "Application Gateway public IP"
  value       = module.application_gateway.public_ip
}

output "key_vault_id" {
  description = "Key Vault ID"
  value       = azurerm_key_vault.openclaw.id
}
