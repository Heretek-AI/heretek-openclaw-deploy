# ==============================================================================
# Heretek OpenClaw - GCP Memorystore Configuration
# ==============================================================================
# Memorystore Redis for OpenClaw caching and session management
# ==============================================================================

# ------------------------------------------------------------------------------
# Memorystore Redis Instance
# ------------------------------------------------------------------------------

resource "google_redis_instance" "openclaw" {
  name           = var.instance_id
  project        = var.project_id
  region         = var.region
  tier           = var.tier
  memory_size_gb = var.memory_size_gb
  redis_version  = var.redis_version

  # Network configuration
  authorized_network = var.network
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  # High availability
  replica_count        = var.replica_count
  read_replicas_enabled = var.read_replicas_enabled

  # Security
  auth_enabled       = var.auth_enabled
  auth_string        = var.auth_string
  transit_encryption_mode = var.transit_encryption_enabled ? "SERVER_AUTHENTICATION" : "DISABLED"

  # Maintenance
  maintenance_policy {
    weekly_maintenance_window {
      day = "TUESDAY"
      start_time {
        hours   = 3
        minutes = 0
        seconds = 0
        nanos   = 0
      }
    }
  }

  # Persistence
  persistence_config {
    persistence_mode = "PERSISTENCE_MODE_ENABLED"
  }

  # Labels
  labels = var.tags

  # Reserved IP range (optional)
  # reserved_ip_range = "10.0.0.0/29"
}

# ------------------------------------------------------------------------------
# Memorystore Instance Configuration (Redis parameters)
# ------------------------------------------------------------------------------

resource "google_redis_instance" "openclaw_config" {
  # This is merged with the main instance above
  # Redis configuration parameters are set via the instance resource
}

# ------------------------------------------------------------------------------
# Secret Manager for Redis Auth
# ------------------------------------------------------------------------------

resource "google_secret_manager_secret" "redis_auth" {
  count = var.auth_enabled ? 1 : 0

  secret_id = "${var.instance_id}-auth"
  project   = var.project_id

  labels = var.tags

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "redis_auth" {
  count = var.auth_enabled ? 1 : 0

  secret = google_secret_manager_secret.redis_auth[0].id

  secret_data = var.auth_string
}

# ------------------------------------------------------------------------------
# Monitoring Alerts
# ------------------------------------------------------------------------------

resource "google_monitoring_alert_policy" "memorystore_cpu" {
  count = var.environment == "prod" ? 1 : 0

  display_name = "${var.instance_id} CPU Utilization"
  project      = var.project_id

  conditions {
    display_name = "CPU utilization > 80%"
    condition_threshold {
      filter          = "resource.type = \"cloud_memorystore_instance\" AND metric.type = \"redis.googleapis.com/memory/usage\" AND resource.label.\"instance_id\" = \"${var.instance_id}\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 80
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.alert_notification_channels

  severity = "WARNING"
}

resource "google_monitoring_alert_policy" "memorystore_memory" {
  count = var.environment == "prod" ? 1 : 0

  display_name = "${var.instance_id} Memory Usage"
  project      = var.project_id

  conditions {
    display_name = "Memory usage > 85%"
    condition_threshold {
      filter          = "resource.type = \"cloud_memorystore_instance\" AND metric.type = \"redis.googleapis.com/memory/usage_ratio\" AND resource.label.\"instance_id\" = \"${var.instance_id}\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.85
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.alert_notification_channels

  severity = "WARNING"
}

resource "google_monitoring_alert_policy" "memorystore_connections" {
  count = var.environment == "prod" ? 1 : 0

  display_name = "${var.instance_id} Connections"
  project      = var.project_id

  conditions {
    display_name = "Connections > 1000"
    condition_threshold {
      filter          = "resource.type = \"cloud_memorystore_instance\" AND metric.type = \"redis.googleapis.com/network/connections\" AND resource.label.\"instance_id\" = \"${var.instance_id}\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 1000
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.alert_notification_channels

  severity = "WARNING"
}

# ------------------------------------------------------------------------------
# Memorystore Backup (Optional)
# ------------------------------------------------------------------------------

resource "google_redis_instance" "openclaw_backup" {
  # Backups are managed through the persistence_config in the main instance
  # Additional backup configurations can be added here
}
