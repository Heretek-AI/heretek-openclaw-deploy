# ==============================================================================
# Heretek OpenClaw - Azure Database for PostgreSQL Configuration
# ==============================================================================
# Azure Database for PostgreSQL Flexible Server for OpenClaw
# ==============================================================================

# ------------------------------------------------------------------------------
# PostgreSQL Flexible Server
# ------------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server" "openclaw" {
  name                = var.server_name
  location            = var.location
  resource_group_name = var.resource_group_name
  version             = var.version
  delegated_subnet_id = var.subnet_id
  zone                = "1"

  sku_name   = var.sku_name
  storage_mb = var.storage_mb
  storage_tier = "Premium"

  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password

  backup {
    backup_retention_days     = var.environment == "prod" ? 35 : 7
    geo_redundant_backup_enabled = var.geo_redundant_backup_enabled
  }

  high_availability {
    mode                      = var.environment == "prod" ? "ZoneRedundant" : "Disabled"
    standby_availability_zone = var.environment == "prod" ? "2" : null
  }

  maintenance_window {
    day_of_week  = 0
    start_hour   = 2
    start_minute = 0
  }

  parameters {
    name  = "azure.extensions"
    value = "PGVECTOR"
  }

  parameters {
    name  = "pg_stat_statements.track"
    value = "all"
  }

  public_network_access_enabled = var.public_network_access_enabled

  tags = var.tags
}

# ------------------------------------------------------------------------------
# PostgreSQL Database
# ------------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server_database" "openclaw" {
  name      = "openclaw"
  server_id = azurerm_postgresql_flexible_server.openclaw.id
  charset   = "UTF8"
  collation = "en_US.UTF8"
}

# ------------------------------------------------------------------------------
# PostgreSQL Firewall Rules
# ------------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_aks" {
  name             = "AllowAKS"
  server_id        = azurerm_postgresql_flexible_server.openclaw.id
  start_ip_address = split("/", var.aks_subnet_cidr)[0]
  end_ip_address   = split("/", var.aks_subnet_cidr)[0]
}

# ------------------------------------------------------------------------------
# PostgreSQL Private DNS Zone
# ------------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "postgresql" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "postgresql-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_a_record" "postgresql" {
  name                = azurerm_postgresql_flexible_server.openclaw.name
  zone_name           = azurerm_private_dns_zone.postgresql.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_postgresql_flexible_server.openclaw.private_ip_address]
  tags                = var.tags
}

# ------------------------------------------------------------------------------
# PostgreSQL Diagnostic Settings
# ------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "postgresql" {
  name                       = "${var.server_name}-diagnostics"
  target_resource_id         = azurerm_postgresql_flexible_server.openclaw.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "PostgreSQLLogs"
  }

  enabled_log {
    category = "QueryStoreRuntimeStatistics"
  }

  enabled_log {
    category = "QueryStoreWaitStatistics"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ------------------------------------------------------------------------------
# PostgreSQL Alerts
# ------------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "postgresql_cpu" {
  count = var.environment == "prod" ? 1 : 0

  name                = "${var.server_name}-cpu-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_postgresql_flexible_server.openclaw.id]
  description         = "CPU utilization is too high"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  severity = 3

  action {
    action_group_id = var.action_group_id
  }
}

resource "azurerm_monitor_metric_alert" "postgresql_storage" {
  count = var.environment == "prod" ? 1 : 0

  name                = "${var.server_name}-storage-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_postgresql_flexible_server.openclaw.id]
  description         = "Storage utilization is too high"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "storage_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  severity = 3

  action {
    action_group_id = var.action_group_id
  }
}

resource "azurerm_monitor_metric_alert" "postgresql_connections" {
  count = var.environment == "prod" ? 1 : 0

  name                = "${var.server_name}-connections-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_postgresql_flexible_server.openclaw.id]
  description         = "Active connections is too high"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "active_connections"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 100
  }

  severity = 3

  action {
    action_group_id = var.action_group_id
  }
}
