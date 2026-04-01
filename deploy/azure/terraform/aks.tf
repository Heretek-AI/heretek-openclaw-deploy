# ==============================================================================
# Heretek OpenClaw - Azure AKS Configuration
# ==============================================================================
# Azure Kubernetes Service cluster for OpenClaw
# ==============================================================================

# ------------------------------------------------------------------------------
# AKS Cluster
# ------------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster" "openclaw_cluster" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = var.default_node_pool.name
    vm_size             = var.default_node_pool.vm_size
    node_count          = var.default_node_pool.node_count
    min_count           = var.default_node_pool.min_count
    max_count           = var.default_node_pool.max_count
    enable_auto_scaling = var.default_node_pool.enable_auto_scaling
    os_disk_size_gb     = var.default_node_pool.os_disk_size_gb
    type                = var.default_node_pool.type
    availability_zones  = var.default_node_pool.availability_zones
    vnet_subnet_id      = var.subnet_id
  }

  identity {
    type = "SystemAssigned"
  }

  # Network configuration
  network_profile {
    network_plugin      = "azure"
    load_balancer_sku   = "standard"
    network_policy      = "calico"
    dns_service_ip      = "10.0.0.10"
    docker_bridge_cidr  = "172.17.0.1/16"
    service_cidr        = "10.1.0.0/16"
    outbound_type       = "loadBalancer"
  }

  # Private cluster configuration
  dynamic "private_cluster_enabled" {
    for_each = var.enable_private_cluster ? [1] : []
    content {
      enabled = var.enable_private_cluster
    }
  }

  # Azure Policy
  azure_policy_enabled = var.enable_azure_policy

  # Monitoring
  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  # Workload Identity
  workload_identity_enabled = var.enable_workload_identity

  # Auto upgrade
  auto_upgrade_channel = "stable"

  # Maintenance window
  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = "Sunday"
    start_time  = "02:00"
    duration    = 4
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = "Saturday"
    start_time  = "02:00"
    duration    = 4
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
}

# ------------------------------------------------------------------------------
# System Node Pool
# ------------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster_node_pool" "system" {
  name                  = var.system_node_pool.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.openclaw_cluster.id
  vm_size               = var.system_node_pool.vm_size
  node_count            = var.system_node_pool.node_count
  min_count             = var.system_node_pool.min_count
  max_count             = var.system_node_pool.max_count
  enable_auto_scaling   = var.system_node_pool.enable_auto_scaling
  os_disk_size_gb       = var.system_node_pool.os_disk_size_gb
  availability_zones    = var.system_node_pool.availability_zones
  vnet_subnet_id        = var.subnet_id

  node_labels = {
    "workload-type" = "system"
    "environment"   = var.environment
  }

  node_taints = [
    "workload-type=system:NoSchedule"
  ]

  tags = var.tags
}

# ------------------------------------------------------------------------------
# User Node Pools
# ------------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each = { for pool in var.user_node_pools : pool.name => pool }

  name                  = each.value.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.openclaw_cluster.id
  vm_size               = each.value.vm_size
  node_count            = each.value.node_count
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  enable_auto_scaling   = each.value.enable_auto_scaling
  os_disk_size_gb       = each.value.os_disk_size_gb
  availability_zones    = each.value.availability_zones
  vnet_subnet_id        = var.subnet_id

  node_labels = {
    "workload-type" = each.value.name
    "environment"   = var.environment
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# GPU Node Pool (Optional)
# ------------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster_node_pool" "gpu" {
  count = var.gpu_enabled ? 1 : 0

  name                  = var.gpu_node_pool.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.openclaw_cluster.id
  vm_size               = var.gpu_node_pool.vm_size
  node_count            = var.gpu_node_pool.node_count
  min_count             = var.gpu_node_pool.min_count
  max_count             = var.gpu_node_pool.max_count
  enable_auto_scaling   = var.gpu_node_pool.enable_auto_scaling
  os_disk_size_gb       = var.gpu_node_pool.os_disk_size_gb
  availability_zones    = var.gpu_node_pool.availability_zones
  vnet_subnet_id        = var.subnet_id

  node_labels = {
    "workload-type" = "gpu"
    "environment"   = var.environment
    "gpu"           = "true"
  }

  node_taints = [
    "nvidia.com/gpu=true:NoSchedule"
  ]

  tags = var.tags
}

# ------------------------------------------------------------------------------
# AKS Role Assignments
# ------------------------------------------------------------------------------

resource "azurerm_role_assignment" "aks_vnet_contributor" {
  scope                = var.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.openclaw_cluster.identity[0].principal_id
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.openclaw_cluster.identity[0].principal_id
}

# ------------------------------------------------------------------------------
# Azure Monitor for Containers
# ------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "${var.cluster_name}-diagnostics"
  target_resource_id         = azurerm_kubernetes_cluster.openclaw_cluster.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "cluster-autoscaler"
  }

  enabled_log {
    category = "guard"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ------------------------------------------------------------------------------
# Kubernetes Manifest Deployments (via Helm)
# ------------------------------------------------------------------------------

resource "helm_release" "nvidia_device_plugin" {
  count = var.gpu_enabled ? 1 : 0

  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  version    = "0.14.1"
  namespace  = "kube-system"

  set {
    name  = "config.map.name"
    value = "nvidia-device-plugin-config"
  }
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.11.0"
  namespace  = "kube-system"
}

resource "helm_release" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.29.0"
  namespace  = "kube-system"

  set {
    name  = "cloudProvider"
    value = "azure"
  }

  set {
    name  = "azureClientID"
    value = azurerm_kubernetes_cluster.openclaw_cluster.identity[0].client_id
  }

  set {
    name  = "azureSubscriptionID"
    value = data.azurerm_client_config.current.subscription_id
  }

  set {
    name  = "azureResourceGroup"
    value = var.resource_group_name
  }

  set {
    name  = "azureClusterName"
    value = var.cluster_name
  }
}
