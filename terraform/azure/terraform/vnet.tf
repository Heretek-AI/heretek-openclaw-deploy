# ==============================================================================
# Heretek OpenClaw - Azure VNet Configuration
# ==============================================================================
# Virtual Network for OpenClaw infrastructure
# ==============================================================================

# ------------------------------------------------------------------------------
# Virtual Network
# ------------------------------------------------------------------------------

resource "azurerm_virtual_network" "openclaw" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space

  dynamic "ddos_protection_plan" {
    for_each = var.enable_ddos_protection ? [1] : []
    content {
      id     = azurerm_ddos_protection_plan.openclaw[0].id
      enable = true
    }
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# DDoS Protection Plan (Optional)
# ------------------------------------------------------------------------------

resource "azurerm_ddos_protection_plan" "openclaw" {
  count = var.enable_ddos_protection ? 1 : 0

  name                = "${var.vnet_name}-ddos"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Subnets
# ------------------------------------------------------------------------------

resource "azurerm_subnet" "aks" {
  name                 = var.subnet_configs.aks.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.openclaw.name
  address_prefixes     = var.subnet_configs.aks.address_prefixes

  delegation {
    name = "aks-delegation"

    service_delegation {
      name    = "Microsoft.ContainerService/managedClusters"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "database" {
  name                 = var.subnet_configs.database.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.openclaw.name
  address_prefixes     = var.subnet_configs.database.address_prefixes

  delegation {
    name = "database-delegation"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/servers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "cache" {
  name                 = var.subnet_configs.cache.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.openclaw.name
  address_prefixes     = var.subnet_configs.cache.address_prefixes

  delegation {
    name = "cache-delegation"

    service_delegation {
      name    = "Microsoft.Cache/redis"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "gateway" {
  name                 = var.subnet_configs.gateway.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.openclaw.name
  address_prefixes     = var.subnet_configs.gateway.address_prefixes

  delegation {
    name = "gateway-delegation"

    service_delegation {
      name    = "Microsoft.Network/applicationGateways"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# ------------------------------------------------------------------------------
# Network Security Groups
# ------------------------------------------------------------------------------

resource "azurerm_network_security_group" "aks" {
  name                = "${var.vnet_name}-aks-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_network_security_group" "database" {
  name                = "${var.vnet_name}-database-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_network_security_group" "cache" {
  name                = "${var.vnet_name}-cache-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_network_security_group" "gateway" {
  name                = "${var.vnet_name}-gateway-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# ------------------------------------------------------------------------------
# NSG Security Rules
# ------------------------------------------------------------------------------

# AKS NSG Rules
resource "azurerm_network_security_rule" "aks_allow_inbound" {
  name                        = "AllowInboundAKS"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "6443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks.name
}

resource "azurerm_network_security_rule" "aks_allow_node" {
  name                        = "AllowNodeCommunication"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "0-65535"
  source_address_prefix       = azurerm_virtual_network.openclaw.address_space[0]
  destination_address_prefix  = azurerm_virtual_network.openclaw.address_space[0]
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks.name
}

# Database NSG Rules
resource "azurerm_network_security_rule" "database_allow_postgresql" {
  name                        = "AllowPostgreSQL"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = azurerm_subnet.aks.address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.database.name
}

# Cache NSG Rules
resource "azurerm_network_security_rule" "cache_allow_redis" {
  name                        = "AllowRedis"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "6379"
  source_address_prefix       = azurerm_subnet.aks.address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.cache.name
}

# Gateway NSG Rules
resource "azurerm_network_security_rule" "gateway_allow_http" {
  name                        = "AllowHTTP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.gateway.name
}

resource "azurerm_network_security_rule" "gateway_allow_https" {
  name                        = "AllowHTTPS"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.gateway.name
}

# ------------------------------------------------------------------------------
# Subnet NSG Associations
# ------------------------------------------------------------------------------

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.database.id
}

resource "azurerm_subnet_network_security_group_association" "cache" {
  subnet_id                 = azurerm_subnet.cache.id
  network_security_group_id = azurerm_network_security_group.cache.id
}

resource "azurerm_subnet_network_security_group_association" "gateway" {
  subnet_id                 = azurerm_subnet.gateway.id
  network_security_group_id = azurerm_network_security_group.gateway.id
}

# ------------------------------------------------------------------------------
# Flow Logs (Optional)
# ------------------------------------------------------------------------------

resource "azurerm_network_watcher" "openclaw" {
  count = var.enable_flow_logs ? 1 : 0

  name                = "${var.vnet_name}-watcher"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_log_analytics_workspace" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name                = "${var.vnet_name}-flow-logs-log"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

resource "azurerm_storage_account" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name                     = "${var.vnet_name}flowlogs"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.tags
}
