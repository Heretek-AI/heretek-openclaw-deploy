# ==============================================================================
# Heretek OpenClaw - Azure Container Registry Configuration
# ==============================================================================
# Azure Container Registry for OpenClaw container images
# ==============================================================================

# ------------------------------------------------------------------------------
# Container Registry
# ------------------------------------------------------------------------------

resource "azurerm_container_registry" "openclaw" {
  name                = var.registry_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = var.environment == "dev"
  zone_redundant      = var.environment == "prod" && var.sku == "Premium"

  # Data endpoint (for Premium SKU)
  data_endpoint_enabled = var.sku == "Premium"

  # Network rules
  network_rule_set {
    default_action = "Deny"
    ip_rule {
      action   = "Allow"
      ip_range = "0.0.0.0/0"  # Allow from AKS VNet
    }
  }

  # Retention policy (Premium SKU only)
  retention_policy_in_days = var.sku == "Premium" ? var.retention_policy_days : null

  # Quarantine policy (Premium SKU only)
  quarantine_policy_enabled = var.quarantine_policy_enabled && var.sku == "Premium"

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Registry Scope Map (for fine-grained access control)
# ------------------------------------------------------------------------------

resource "azurerm_container_registry_scope_map" "openclaw_pull" {
  name                    = "openclaw-pull-scope"
  container_registry_name = var.registry_name
  resource_group_name     = var.resource_group_name

  actions = [
    "repositories/*/pull",
  ]
}

resource "azurerm_container_registry_scope_map" "openclaw_push" {
  name                    = "openclaw-push-scope"
  container_registry_name = var.registry_name
  resource_group_name     = var.resource_group_name

  actions = [
    "repositories/*/pull",
    "repositories/*/push",
  ]
}

# ------------------------------------------------------------------------------
# Registry Token (for authentication)
# ------------------------------------------------------------------------------

resource "azurerm_container_registry_token" "openclaw_pull" {
  name                    = "openclaw-pull-token"
  container_registry_name = var.registry_name
  resource_group_name     = var.resource_group_name
  scope_map_id            = azurerm_container_registry_scope_map.openclaw_pull.id
}

resource "azurerm_container_registry_token" "openclaw_push" {
  name                    = "openclaw-push-token"
  container_registry_name = var.registry_name
  resource_group_name     = var.resource_group_name
  scope_map_id            = azurerm_container_registry_scope_map.openclaw_push.id
}

# ------------------------------------------------------------------------------
# Registry Task (for automated builds)
# ------------------------------------------------------------------------------

resource "azurerm_container_registry_task" "openclaw_gateway" {
  name                    = "build-openclaw-gateway"
  container_registry_name = var.registry_name
  resource_group_name     = var.resource_group_name

  platform {
    os                = "Linux"
    os_version        = "20.04"
    architecture      = "amd64"
  }

  agent_setting {
    cpu    = "4"
    memory = "8"
  }

  step {
    source_value = "https://github.com/Heretek-AI/heretek-openclaw.git"
    context_path = ""
    dockerfile_path = "Dockerfile"
    image_names = [
      "${var.registry_name}.azurecr.io/openclaw-gateway:{{.Run.ID}}",
      "${var.registry_name}.azurecr.io/openclaw-gateway:latest",
    ]
    push_enabled = true
  }

  enabled = false  # Disabled by default, enable via CI/CD

  tags = var.tags
}

resource "azurerm_container_registry_task" "litellm_proxy" {
  name                    = "build-litellm-proxy"
  container_registry_name = var.registry_name
  resource_group_name     = var.resource_group_name

  platform {
    os                = "Linux"
    os_version        = "20.04"
    architecture      = "amd64"
  }

  agent_setting {
    cpu    = "2"
    memory = "4"
  }

  step {
    source_value = "https://github.com/Heretek-AI/heretek-openclaw.git"
    context_path = ""
    dockerfile_path = "Dockerfile.litellm"
    image_names = [
      "${var.registry_name}.azurecr.io/litellm-proxy:{{.Run.ID}}",
      "${var.registry_name}.azurecr.io/litellm-proxy:latest",
    ]
    push_enabled = true
  }

  enabled = false  # Disabled by default, enable via CI/CD

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Registry Webhook (for CI/CD integration)
# ------------------------------------------------------------------------------

resource "azurerm_container_registry_webhook" "openclaw_gateway" {
  name                    = "openclaw-gateway-webhook"
  location                = var.location
  resource_group_name     = var.resource_group_name
  container_registry_name = var.registry_name
  service_uri             = var.webhook_service_uri  # CI/CD endpoint
  scope                   = "openclaw-gateway:.*"
  actions                 = ["push"]
  status                  = "enabled"
}

# ------------------------------------------------------------------------------
# Registry Agent Pool (for dedicated build resources)
# ------------------------------------------------------------------------------

resource "azurerm_container_registry_agent_pool" "openclaw" {
  count = var.sku == "Premium" ? 1 : 0

  name                    = "openclaw-pool"
  resource_group_name     = var.resource_group_name
  container_registry_name = var.registry_name
  sku                     = "Dedicated"
  os_type                 = "Linux"

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Registry Diagnostic Settings
# ------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "${var.registry_name}-diagnostics"
  target_resource_id         = azurerm_container_registry.openclaw.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ------------------------------------------------------------------------------
# Registry Alerts
# ------------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "acr_storage" {
  count = var.environment == "prod" ? 1 : 0

  name                = "${var.registry_name}-storage-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_container_registry.openclaw.id]
  description         = "Registry storage is running low"

  criteria {
    metric_namespace = "Microsoft.ContainerRegistry/registries"
    metric_name      = "Size"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.storage_threshold_gb * 1024 * 1024 * 1024  # Convert to bytes
  }

  severity = 3

  action {
    action_group_id = var.action_group_id
  }
}
