# ==============================================================================
# Heretek OpenClaw - Azure Terraform Outputs
# ==============================================================================
# Output values for Azure infrastructure
# ==============================================================================

# ------------------------------------------------------------------------------
# Resource Group Outputs
# ------------------------------------------------------------------------------

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.openclaw.name
}

output "resource_group_location" {
  description = "Resource group location"
  value       = azurerm_resource_group.openclaw.location
}

# ------------------------------------------------------------------------------
# VNet Outputs
# ------------------------------------------------------------------------------

output "vnet_id" {
  description = "VNet ID"
  value       = module.vnet.vnet_id
}

output "vnet_name" {
  description = "VNet name"
  value       = module.vnet.vnet_name
}

output "vnet_address_space" {
  description = "VNet address space"
  value       = module.vnet.vnet_address_space
}

output "aks_subnet_id" {
  description = "AKS subnet ID"
  value       = module.vnet.aks_subnet_id
}

output "database_subnet_id" {
  description = "Database subnet ID"
  value       = module.vnet.database_subnet_id
}

output "cache_subnet_id" {
  description = "Cache subnet ID"
  value       = module.vnet.cache_subnet_id
}

output "gateway_subnet_id" {
  description = "Gateway subnet ID"
  value       = module.vnet.gateway_subnet_id
}

# ------------------------------------------------------------------------------
# AKS Outputs
# ------------------------------------------------------------------------------

output "aks_cluster_id" {
  description = "AKS cluster ID"
  value       = azurerm_kubernetes_cluster.openclaw_cluster.id
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.openclaw_cluster.name
}

output "aks_cluster_fqdn" {
  description = "AKS cluster FQDN"
  value       = azurerm_kubernetes_cluster.openclaw_cluster.fqdn
}

output "aks_cluster_kubernetes_version" {
  description = "AKS cluster Kubernetes version"
  value       = azurerm_kubernetes_cluster.openclaw_cluster.kubernetes_version
}

output "aks_cluster_node_resource_group" {
  description = "AKS cluster node resource group"
  value       = azurerm_kubernetes_cluster.openclaw_cluster.node_resource_group
}

output "aks_cluster_identity_principal_id" {
  description = "AKS cluster identity principal ID"
  value       = azurerm_kubernetes_cluster.openclaw_cluster.identity[0].principal_id
}

output "aks_kube_config_raw" {
  description = "Raw kube config"
  value       = azurerm_kubernetes_cluster.openclaw_cluster.kube_config_raw
  sensitive   = true
}

output "aks_kube_config_host" {
  description = "Kube config host"
  value       = azurerm_kubernetes_cluster.openclaw_cluster.kube_config[0].host
  sensitive   = true
}

output "aks_kube_config_command" {
  description = "Command to get AKS credentials"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.openclaw.name} --name ${azurerm_kubernetes_cluster.openclaw_cluster.name}"
}

# ------------------------------------------------------------------------------
# PostgreSQL Outputs
# ------------------------------------------------------------------------------

output "postgresql_server_id" {
  description = "PostgreSQL server ID"
  value       = module.postgresql.server_id
}

output "postgresql_server_name" {
  description = "PostgreSQL server name"
  value       = module.postgresql.server_name
}

output "postgresql_fqdn" {
  description = "PostgreSQL server FQDN"
  value       = module.postgresql.fqdn
}

output "postgresql_port" {
  description = "PostgreSQL server port"
  value       = module.postgresql.port
}

output "postgresql_administrator_login" {
  description = "PostgreSQL administrator login"
  value       = module.postgresql.administrator_login
  sensitive   = true
}

output "postgresql_connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${var.db_administrator_login}:${var.db_administrator_password}@${module.postgresql.fqdn}:5432/postgres"
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Redis Outputs
# ------------------------------------------------------------------------------

output "redis_cache_id" {
  description = "Redis cache ID"
  value       = module.redis.redis_cache_id
}

output "redis_cache_name" {
  description = "Redis cache name"
  value       = module.redis.redis_cache_name
}

output "redis_hostname" {
  description = "Redis cache hostname"
  value       = module.redis.hostname
}

output "redis_port" {
  description = "Redis cache port"
  value       = module.redis.port
}

output "redis_connection_string" {
  description = "Redis connection string"
  value       = "redis://${var.redis_password != null ? ":${var.redis_password}@" : ""}${module.redis.hostname}:${module.redis.port}"
  sensitive   = true
}

# ------------------------------------------------------------------------------
# ACR Outputs
# ------------------------------------------------------------------------------

output "acr_id" {
  description = "ACR ID"
  value       = module.acr.acr_id
}

output "acr_name" {
  description = "ACR name"
  value       = module.acr.acr_name
}

output "acr_login_server" {
  description = "ACR login server"
  value       = module.acr.login_server
}

output "acr_login_server_url" {
  description = "ACR login server URL"
  value       = "https://${module.acr.login_server}"
}

output "acr_admin_username" {
  description = "ACR admin username"
  value       = module.acr.admin_username
}

output "acr_admin_password" {
  description = "ACR admin password"
  value       = module.acr.admin_password
  sensitive   = true
}

output "acr_login_command" {
  description = "ACR login command"
  value       = "az acr login --name ${module.acr.acr_name}"
}

# ------------------------------------------------------------------------------
# Application Gateway Outputs
# ------------------------------------------------------------------------------

output "application_gateway_id" {
  description = "Application Gateway ID"
  value       = module.application_gateway.gateway_id
}

output "application_gateway_name" {
  description = "Application Gateway name"
  value       = module.application_gateway.gateway_name
}

output "application_gateway_public_ip" {
  description = "Application Gateway public IP"
  value       = module.application_gateway.public_ip
}

output "application_gateway_public_ip_id" {
  description = "Application Gateway public IP ID"
  value       = module.application_gateway.public_ip_id
}

# ------------------------------------------------------------------------------
# Key Vault Outputs
# ------------------------------------------------------------------------------

output "key_vault_id" {
  description = "Key Vault ID"
  value       = azurerm_key_vault.openclaw.id
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.openclaw.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.openclaw.vault_uri
}

# ------------------------------------------------------------------------------
# Monitoring Outputs
# ------------------------------------------------------------------------------

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  value       = module.monitoring.log_analytics_workspace_id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace name"
  value       = module.monitoring.log_analytics_workspace_name
}

output "application_insights_id" {
  description = "Application Insights ID"
  value       = module.monitoring.application_insights_id
}

output "monitoring_dashboard_id" {
  description = "Monitoring dashboard ID"
  value       = module.monitoring.dashboard_id
}

# ------------------------------------------------------------------------------
# Cost Estimation
# ------------------------------------------------------------------------------

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    aks_cluster         = "~$73 (cluster management)"
    aks_nodes_default   = "~$${var.default_node_pool.node_count * 140} (${var.default_node_pool.vm_size})"
    aks_nodes_system    = "~$${var.system_node_pool.node_count * 70} (${var.system_node_pool.vm_size})"
    aks_nodes_compute   = "~$${var.user_node_pools[0].node_count * 350} (${var.user_node_pools[0].vm_size})"
    aks_nodes_gpu       = local.gpu_enabled ? "~$${var.gpu_node_pool.node_count * 2500} (${var.gpu_node_pool.vm_size})" : "$0"
    postgresql          = "~$${var.postgresql_sku_name == "GP_Gen5_2" ? 150 : 300} (${var.postgresql_sku_name})"
    redis               = "~$${var.redis_sku_name == "Standard" ? 100 : 200} (${var.redis_capacity}GB)"
    acr                 = "~$10 (Standard)"
    application_gateway = "~$30 (Standard_v2)"
    key_vault           = "~$5"
    monitoring          = "~$50"
    network_egress      = "Variable"
    total_estimate      = "See Azure Pricing Calculator for accurate pricing"
  }
}
