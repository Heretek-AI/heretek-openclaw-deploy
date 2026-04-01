# ==============================================================================
# Heretek OpenClaw - Monitoring Terraform Module
# ==============================================================================
# Reusable module for monitoring stack (Prometheus, Grafana, Alerting)
# ==============================================================================

# ------------------------------------------------------------------------------
# Module Variables
# ------------------------------------------------------------------------------

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# Cloud Provider Specific Variables
# ------------------------------------------------------------------------------

variable "cloud_provider" {
  description = "Cloud provider (aws, gcp, azure)"
  type        = string
  validation {
    condition     = contains(["aws", "gcp", "azure"], var.cloud_provider)
    error_message = "Cloud provider must be one of: aws, gcp, azure."
  }
}

variable "project_id" {
  description = "GCP project ID or Azure subscription ID"
  type        = string
  default     = null
}

variable "region" {
  description = "Cloud provider region"
  type        = string
}

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# Cluster Configuration
# ------------------------------------------------------------------------------

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = null
}

variable "cluster_id" {
  description = "Kubernetes cluster ID"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# Database Configuration
# ------------------------------------------------------------------------------

variable "database_instance_id" {
  description = "Database instance identifier"
  type        = string
  default     = null
}

variable "database_instance_name" {
  description = "Database instance name"
  type        = string
  default     = null
}

variable "database_server_id" {
  description = "Database server ID (Azure)"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# Cache Configuration
# ------------------------------------------------------------------------------

variable "cache_cluster_id" {
  description = "Cache cluster identifier"
  type        = string
  default     = null
}

variable "cache_instance_id" {
  description = "Cache instance identifier"
  type        = string
  default     = null
}

variable "redis_cache_id" {
  description = "Redis cache ID (Azure)"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# Dashboard Configuration
# ------------------------------------------------------------------------------

variable "enable_dashboard" {
  description = "Enable monitoring dashboard"
  type        = bool
  default     = true
}

variable "dashboard_name" {
  description = "Dashboard name"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# Alerting Configuration
# ------------------------------------------------------------------------------

variable "enable_alerts" {
  description = "Enable alerting rules"
  type        = bool
  default     = true
}

variable "alert_notification_arn" {
  description = "SNS topic ARN (AWS)"
  type        = string
  default     = null
}

variable "alert_email" {
  description = "Email for alert notifications"
  type        = string
  default     = null
}

variable "alert_notification_channels" {
  description = "Alert notification channel IDs (GCP)"
  type        = list(string)
  default     = []
}

variable "action_group_id" {
  description = "Action group ID (Azure)"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# Log Configuration
# ------------------------------------------------------------------------------

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 30
}

variable "enable_log_export" {
  description = "Enable log export to storage"
  type        = bool
  default     = false
}

variable "log_storage_bucket" {
  description = "Storage bucket for log export"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# Local Values
# ------------------------------------------------------------------------------

locals {
  common_tags = merge(var.tags, {
    "app.kubernetes.io/name"       = "monitoring"
    "app.kubernetes.io/component"  = "observability"
    "app.kubernetes.io/part-of"    = "openclaw"
    "app.kubernetes.io/managed-by" = "terraform"
  })
  
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "${var.name_prefix}-dashboard"
  
  alert_prefix = "${var.name_prefix}-alert"
}

# ------------------------------------------------------------------------------
# AWS Resources
# ------------------------------------------------------------------------------

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "openclaw" {
  count = var.cloud_provider == "aws" && var.enable_dashboard ? 1 : 0

  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EKS Cluster CPU Utilization"
          region = var.region
          metrics = [
            ["AWS/EKS", "CPUUtilization", "ClusterName", var.cluster_name, { stat = "Average" }]
          ]
          view = "timeSeries"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "RDS CPU Utilization"
          region = var.region
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.database_instance_id, { stat = "Average" }]
          ]
          view = "timeSeries"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ElastiCache CPU Utilization"
          region = var.region
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", var.cache_cluster_id, { stat = "Average" }]
          ]
          view = "timeSeries"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB Request Count"
          region = var.region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.name_prefix, { stat = "Sum" }]
          ]
          view = "timeSeries"
          period = 300
        }
      }
    ]
  })
}

# CloudWatch Alarms - EKS
resource "aws_cloudwatch_metric_alarm" "eks_cpu" {
  count = var.cloud_provider == "aws" && var.enable_alerts ? 1 : 0

  alarm_name          = "${local.alert_prefix}-eks-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EKS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EKS cluster CPU utilization is too high"
  alarm_actions       = var.alert_notification_arn != null ? [var.alert_notification_arn] : []
  ok_actions          = var.alert_notification_arn != null ? [var.alert_notification_arn] : []

  dimensions = {
    ClusterName = var.cluster_name
  }
}

# CloudWatch Alarms - RDS
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count = var.cloud_provider == "aws" && var.enable_alerts ? 1 : 0

  alarm_name          = "${local.alert_prefix}-rds-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization is too high"
  alarm_actions       = var.alert_notification_arn != null ? [var.alert_notification_arn] : []

  dimensions = {
    DBInstanceIdentifier = var.database_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  count = var.cloud_provider == "aws" && var.enable_alerts ? 1 : 0

  alarm_name          = "${local.alert_prefix}-rds-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 10737418240  # 10GB
  alarm_description   = "RDS free storage space is too low"
  alarm_actions       = var.alert_notification_arn != null ? [var.alert_notification_arn] : []

  dimensions = {
    DBInstanceIdentifier = var.database_instance_id
  }
}

# CloudWatch Alarms - ElastiCache
resource "aws_cloudwatch_metric_alarm" "elasticache_cpu" {
  count = var.cloud_provider == "aws" && var.enable_alerts ? 1 : 0

  alarm_name          = "${local.alert_prefix}-elasticache-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ElastiCache CPU utilization is too high"
  alarm_actions       = var.alert_notification_arn != null ? [var.alert_notification_arn] : []

  dimensions = {
    CacheClusterId = var.cache_cluster_id
  }
}

resource "aws_cloudwatch_metric_alarm" "elasticache_memory" {
  count = var.cloud_provider == "aws" && var.enable_alerts ? 1 : 0

  alarm_name          = "${local.alert_prefix}-elasticache-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 268435456  # 256MB
  alarm_description   = "ElastiCache freeable memory is too low"
  alarm_actions       = var.alert_notification_arn != null ? [var.alert_notification_arn] : []

  dimensions = {
    CacheClusterId = var.cache_cluster_id
  }
}

# ------------------------------------------------------------------------------
# GCP Resources
# ------------------------------------------------------------------------------

# Cloud Monitoring Dashboard
resource "google_monitoring_dashboard" "openclaw" {
  count = var.cloud_provider == "gcp" && var.enable_dashboard ? 1 : 0

  dashboard_json = jsonencode({
    displayName = local.dashboard_name
    gridLayout = {
      columns = 2
      widgets = [
        {
          title = "GKE Cluster CPU"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                apiSource = "CLOUD_MONITORING_API"
                timeSeriesFilter = {
                  filter = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/cpu/limit_utilization\""
                  aggregation = {
                    alignmentPeriod    = "300s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_MEAN"
                    groupByFields      = ["resource.label.\"cluster_name\""]
                  }
                }
              }
            }]
          }
        },
        {
          title = "Cloud SQL CPU"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                apiSource = "CLOUD_MONITORING_API"
                timeSeriesFilter = {
                  filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
                  aggregation = {
                    alignmentPeriod    = "300s"
                    perSeriesAligner   = "ALIGN_MEAN"
                  }
                }
              }
            }]
          }
        },
        {
          title = "Memorystore Memory"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                apiSource = "CLOUD_MONITORING_API"
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_memorystore_instance\" AND metric.type=\"redis.googleapis.com/memory/usage_ratio\""
                }
              }
            }]
          }
        }
      ]
    }
  })
}

# GCP Alert Policies
resource "google_monitoring_alert_policy" "gke_cpu" {
  count = var.cloud_provider == "gcp" && var.enable_alerts ? 1 : 0

  display_name = "${local.alert_prefix}-gke-cpu"
  project      = var.project_id

  conditions {
    display_name = "GKE CPU utilization > 80%"
    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/cpu/limit_utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.alert_notification_channels
  severity              = "WARNING"
}

resource "google_monitoring_alert_policy" "cloud_sql_cpu" {
  count = var.cloud_provider == "gcp" && var.enable_alerts && var.database_instance_name != null ? 1 : 0

  display_name = "${local.alert_prefix}-cloud-sql-cpu"
  project      = var.project_id

  conditions {
    display_name = "Cloud SQL CPU utilization > 80%"
    condition_threshold {
      filter          = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\" AND resource.label.\"database_id\" = \"${var.database_instance_name}\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 80
    }
  }

  notification_channels = var.alert_notification_channels
  severity              = "WARNING"
}

# ------------------------------------------------------------------------------
# Azure Resources
# ------------------------------------------------------------------------------

# Azure Monitor Dashboard
resource "azurerm_dashboard" "openclaw" {
  count = var.cloud_provider == "azure" && var.enable_dashboard ? 1 : 0

  name                = local.dashboard_name
  resource_group_name = var.resource_group_name
  location            = var.region
  tags                = local.common_tags

  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          "0" = {
            position = { x = 0, y = 0, colSpan = 2, rowSpan = 1 }
            metadata = {
              inputs = []
              type   = "Extension/HubsExtension/PartType/MonitorChartPart"
              settings = {
                content = {
                  options = {
                    chart = {
                      metrics = [{
                        resourceMetadata = { id = var.cluster_id }
                        name             = "cpuUsagePercentage"
                        namespace        = "Insights.Container/containers"
                      }]
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  })
}

# Azure Monitor Alerts
resource "azurerm_monitor_metric_alert" "aks_cpu" {
  count = var.cloud_provider == "azure" && var.enable_alerts && var.cluster_id != null ? 1 : 0

  name                = "${local.alert_prefix}-aks-cpu"
  resource_group_name = var.resource_group_name
  scopes              = [var.cluster_id]
  description         = "AKS cluster CPU utilization is too high"

  criteria {
    metric_namespace = "Insights.Container/containers"
    metric_name      = "cpuUsagePercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  severity = 3

  dynamic "action" {
    for_each = var.action_group_id != null ? [1] : []
    content {
      action_group_id = var.action_group_id
    }
  }
}

resource "azurerm_monitor_metric_alert" "postgresql_cpu" {
  count = var.cloud_provider == "azure" && var.enable_alerts && var.database_server_id != null ? 1 : 0

  name                = "${local.alert_prefix}-postgresql-cpu"
  resource_group_name = var.resource_group_name
  scopes              = [var.database_server_id]
  description         = "PostgreSQL CPU utilization is too high"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  severity = 3

  dynamic "action" {
    for_each = var.action_group_id != null ? [1] : []
    content {
      action_group_id = var.action_group_id
    }
  }
}

resource "azurerm_monitor_metric_alert" "redis_cpu" {
  count = var.cloud_provider == "azure" && var.enable_alerts && var.redis_cache_id != null ? 1 : 0

  name                = "${local.alert_prefix}-redis-cpu"
  resource_group_name = var.resource_group_name
  scopes              = [var.redis_cache_id]
  description         = "Redis CPU utilization is too high"

  criteria {
    metric_namespace = "Microsoft.Cache/Redis"
    metric_name      = "UsedMemoryPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  severity = 3

  dynamic "action" {
    for_each = var.action_group_id != null ? [1] : []
    content {
      action_group_id = var.action_group_id
    }
  }
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------

output "dashboard_id" {
  description = "Dashboard ID"
  value = var.cloud_provider == "aws" ? (
    length(aws_cloudwatch_dashboard.openclaw) > 0 ? aws_cloudwatch_dashboard.openclaw[0].dashboard_name : null
  ) : var.cloud_provider == "gcp" ? (
    length(google_monitoring_dashboard.openclaw) > 0 ? google_monitoring_dashboard.openclaw[0].id : null
  ) : var.cloud_provider == "azure" ? (
    length(azurerm_dashboard.openclaw) > 0 ? azurerm_dashboard.openclaw[0].id : null
  ) : null
}

output "dashboard_name" {
  description = "Dashboard name"
  value       = local.dashboard_name
}

output "alarm_ids" {
  description = "List of alarm IDs"
  value = var.cloud_provider == "aws" ? concat(
    aws_cloudwatch_metric_alarm.eks_cpu[*].id,
    aws_cloudwatch_metric_alarm.rds_cpu[*].id,
    aws_cloudwatch_metric_alarm.rds_storage[*].id,
    aws_cloudwatch_metric_alarm.elasticache_cpu[*].id,
    aws_cloudwatch_metric_alarm.elasticache_memory[*].id
  ) : var.cloud_provider == "gcp" ? concat(
    google_monitoring_alert_policy.gke_cpu[*].id,
    google_monitoring_alert_policy.cloud_sql_cpu[*].id
  ) : []
}

output "alert_policy_ids" {
  description = "List of alert policy IDs"
  value = var.cloud_provider == "gcp" ? concat(
    google_monitoring_alert_policy.gke_cpu[*].id,
    google_monitoring_alert_policy.cloud_sql_cpu[*].id
  ) : []
}

output "log_group_names" {
  description = "Map of CloudWatch log group names"
  value = var.cloud_provider == "aws" ? {
    eks       = "/aws/containerinsights/${var.cluster_name}/application"
    cluster   = "/aws/containerinsights/${var.cluster_name}/dataplane"
  } : {}
}
