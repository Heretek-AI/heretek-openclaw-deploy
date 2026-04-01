# ==============================================================================
# Heretek OpenClaw - Azure Cache for Redis Configuration
# ==============================================================================
# Azure Cache for Redis for OpenClaw caching and session management
# ==============================================================================

# ------------------------------------------------------------------------------
# Redis Cache
# ------------------------------------------------------------------------------

resource "azurerm_redis_cache" "openclaw" {
  name                = var.cache_name
  location            = var.location
  resource_group_name = var.resource_group_name
  capacity            = var.capacity
  family              = var.family
  sku_name            = var.sku_name
  redis_version       = var.redis_version

  enable_non_ssl_port = var.enable_non_ssl_port
  minimum_tls_version = var.minimum_tls_version

  redis_configuration {
    maxmemory_reserved = var.capacity * 1024
    maxmemory_delta    = var.capacity * 1024
    maxmemory_policy   = "allkeys-lru"
    notify_keyspace_events = "KEA"
  }

  # Private endpoint
  private_endpoint {
    name      = "${var.cache_name}-pe"
    subnet_id = var.subnet_id
  }

  tags = var.tags

  zones = var.zones
}

# ------------------------------------------------------------------------------
# Redis Private Endpoint
# ------------------------------------------------------------------------------

resource "azurerm_private_endpoint" "redis" {
  name                = "${var.cache_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.cache_name}-psc"
    private_connection_resource_id = azurerm_redis_cache.openclaw.id
    is_manual_connection           = false
    subresource_names              = ["redisCache"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis.id]
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Redis Private DNS Zone
# ------------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "redis-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.redis.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

# ------------------------------------------------------------------------------
# Redis Firewall Rules (for Premium tier)
# ------------------------------------------------------------------------------

resource "azurerm_redis_firewall_rule" "allow_aks" {
  count = var.sku_name == "Premium" ? 1 : 0

  name                = "AllowAKS"
  redis_cache_name    = azurerm_redis_cache.openclaw.name
  resource_group_name = var.resource_group_name
  start_ip            = split("/", var.aks_subnet_cidr)[0]
  end_ip              = split("/", var.aks_subnet_cidr)[0]
}

# ------------------------------------------------------------------------------
# Redis Patch Schedule
# ------------------------------------------------------------------------------

resource "azurerm_redis_cache_patch_schedule" "openclaw" {
  redis_cache_id        = azurerm_redis_cache.openclaw.id
  time_zone_name        = "UTC"
  maintenance_window    = "03:00-05:00"
  day_of_week           = "Sunday"
  schedule_updates_enabled = true
}

# ------------------------------------------------------------------------------
# Redis Diagnostic Settings
# ------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "redis" {
  name                       = "${var.cache_name}-diagnostics"
  target_resource_id         = azurerm_redis_cache.openclaw.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "CacheMetrics"
  }

  enabled_log {
    category = "CacheRequests"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ------------------------------------------------------------------------------
# Redis Alerts
# ------------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "redis_cpu" {
  count = var.environment == "prod" ? 1 : 0

  name                = "${var.cache_name}-cpu-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_redis_cache.openclaw.id]
  description         = "CPU utilization is too high"

  criteria {
    metric_namespace = "Microsoft.Cache/Redis"
    metric_name      = "UsedMemoryPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  severity = 3

  action {
    action_group_id = var.action_group_id
  }
}

resource "azurerm_monitor_metric_alert" "redis_connections" {
  count = var.environment == "prod" ? 1 : 0

  name                = "${var.cache_name}-connections-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_redis_cache.openclaw.id]
  description         = "Connected clients is too high"

  criteria {
    metric_namespace = "Microsoft.Cache/Redis"
    metric_name      = "ConnectedClients"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 100
  }

  severity = 3

  action {
    action_group_id = var.action_group_id
  }
}

resource "azurerm_monitor_metric_alert" "redis_timeout" {
  count = var.environment == "prod" ? 1 : 0

  name                = "${var.cache_name}-timeout-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_redis_cache.openclaw.id]
  description         = "Server busy/timeout count is too high"

  criteria {
    metric_namespace = "Microsoft.Cache/Redis"
    metric_name      = "ServerBusy"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 10
  }

  severity = 2

  action {
    action_group_id = var.action_group_id
  }
}
