# ==============================================================================
# Heretek OpenClaw - Azure Application Gateway Configuration
# ==============================================================================
# Application Gateway for OpenClaw traffic routing and SSL termination
# ==============================================================================

# ------------------------------------------------------------------------------
# Public IP for Application Gateway
# ------------------------------------------------------------------------------

resource "azurerm_public_ip" "gateway" {
  name                = "${var.gateway_name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.domain_name_label

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Application Gateway
# ------------------------------------------------------------------------------

resource "azurerm_application_gateway" "openclaw" {
  name                = var.gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = var.sku_name
    tier     = var.sku_name
    capacity = var.capacity
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.subnet_id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.gateway.id
  }

  backend_address_pool {
    name = "openclaw-gateway-pool"
  }

  backend_address_pool {
    name = "litellm-proxy-pool"
  }

  backend_http_settings {
    name                  = "gateway-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 18789
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = "gateway-probe"
  }

  backend_http_settings {
    name                  = "litellm-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 4000
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = "litellm-probe"
  }

  # Health Probes
  probe {
    name                                      = "gateway-probe"
    protocol                                  = "Http"
    path                                      = "/health"
    interval                                  = 30
    timeout                                   = 5
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = false
  }

  probe {
    name                                      = "litellm-probe"
    protocol                                  = "Http"
    path                                      = "/health"
    interval                                  = 30
    timeout                                   = 5
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = false
  }

  # HTTP Listener
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  # HTTPS Listener (if SSL certificate provided)
  dynamic "http_listener" {
    for_each = var.ssl_certificate_data != null ? [1] : []
    content {
      name                           = "https-listener"
      frontend_ip_configuration_name = "frontend-ip-config"
      frontend_port_name             = "https-port"
      protocol                       = "Https"
      ssl_certificate_name           = "ssl-cert"
    }
  }

  # SSL Certificate (if provided)
  dynamic "ssl_certificate" {
    for_each = var.ssl_certificate_data != null ? [1] : []
    content {
      name     = "ssl-cert"
      data     = var.ssl_certificate_data
      password = var.ssl_certificate_password
    }
  }

  # Request Routing Rules
  request_routing_rule {
    name                       = "http-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "openclaw-gateway-pool"
    backend_http_settings_name = "gateway-http-settings"
    priority                   = 200
  }

  # HTTPS Routing Rule (if SSL enabled)
  dynamic "request_routing_rule" {
    for_each = var.ssl_certificate_data != null ? [1] : []
    content {
      name                       = "https-routing-rule"
      rule_type                  = "Basic"
      http_listener_name         = "https-listener"
      backend_address_pool_name  = "openclaw-gateway-pool"
      backend_http_settings_name = "gateway-http-settings"
      priority                   = 100
    }
  }

  # URL Path Map for path-based routing
  url_path_map {
    name                               = "url-path-map"
    default_backend_address_pool_name  = "openclaw-gateway-pool"
    default_backend_http_settings_name = "gateway-http-settings"

    path_rule {
      name                       = "litellm-path-rule"
      paths                      = ["/v1/*", "/litellm/*"]
      backend_address_pool_name  = "litellm-proxy-pool"
      backend_http_settings_name = "litellm-http-settings"
    }

    path_rule {
      name                       = "websocket-path-rule"
      paths                      = ["/ws/*", "/gateway/*"]
      backend_address_pool_name  = "openclaw-gateway-pool"
      backend_http_settings_name = "gateway-http-settings"
    }
  }

  # HTTPS with URL Path Map
  dynamic "request_routing_rule" {
    for_each = var.ssl_certificate_data != null ? [1] : []
    content {
      name               = "https-path-routing-rule"
      rule_type          = "PathBasedRouting"
      http_listener_name = "https-listener"
      url_path_map_name  = "url-path-map"
      priority           = 150
    }
  }

  # Autoscale configuration
  autoscale_configuration {
    min_capacity = var.autoscale_min_capacity
    max_capacity = var.autoscale_max_capacity
  }

  # WAF Configuration (for WAF SKU)
  dynamic "waf_configuration" {
    for_each = var.sku_name == "WAF_v2" ? [1] : []
    content {
      enabled                  = true
      firewall_mode            = "Prevention"
      rule_set_type            = "OWASP"
      rule_set_version         = "3.2"
      request_body_check       = true
      max_request_body_size_kb = 128
    }
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Application Gateway Diagnostic Settings
# ------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "gateway" {
  name                       = "${var.gateway_name}-diagnostics"
  target_resource_id         = azurerm_application_gateway.openclaw.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ------------------------------------------------------------------------------
# Application Gateway Alerts
# ------------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "gateway_capacity" {
  count = var.environment == "prod" ? 1 : 0

  name                = "${var.gateway_name}-capacity-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_gateway.openclaw.id]
  description         = "Application Gateway capacity is high"

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "ApplicationGatewayCapacityUnits"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.capacity * 0.8
  }

  severity = 3

  action {
    action_group_id = var.action_group_id
  }
}

resource "azurerm_monitor_metric_alert" "gateway_response_time" {
  count = var.environment == "prod" ? 1 : 0

  name                = "${var.gateway_name}-response-time-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_gateway.openclaw.id]
  description         = "Application Gateway response time is too high"

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "ApplicationGatewayTimeTaken"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 5000  # 5 seconds
  }

  severity = 3

  action {
    action_group_id = var.action_group_id
  }
}

resource "azurerm_monitor_metric_alert" "gateway_failures" {
  count = var.environment == "prod" ? 1 : 0

  name                = "${var.gateway_name}-failures-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_gateway.openclaw.id]
  description         = "Application Gateway backend failures are high"

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "ApplicationGatewayFailedBackends"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }

  severity = 2

  action {
    action_group_id = var.action_group_id
  }
}
