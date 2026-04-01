# ==============================================================================
# Heretek OpenClaw - GCP Cloud SQL Configuration
# ==============================================================================
# Cloud SQL PostgreSQL database for OpenClaw
# ==============================================================================

# ------------------------------------------------------------------------------
# Cloud SQL Instance
# ------------------------------------------------------------------------------

resource "google_sql_database_instance" "openclaw" {
  name             = var.instance_name
  project          = var.project_id
  region           = var.region
  database_version = var.database_version
  deletion_protection = var.environment == "prod"

  settings {
    tier              = var.tier
    disk_size         = var.disk_size
    disk_type         = var.disk_type
    availability_type = var.high_availability ? "REGIONAL" : "ZONAL"

    # Backup configuration
    backup_configuration {
      enabled                        = var.backup_enabled
      start_time                     = var.backup_start_time
      point_in_time_recovery_enabled = var.point_in_time_recovery
      transaction_log_retention_days = var.backup_enabled ? 7 : null
    }

    # IP configuration
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network
      require_ssl     = true
    }

    # Query insights
    insights_config {
      query_insights_enabled  = var.query_insights_enabled
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }

    # Maintenance
    maintenance_window {
      day          = 1
      hour         = 3
      update_track = "stable"
    }

    # Labels
    user_labels = var.tags
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# ------------------------------------------------------------------------------
# Cloud SQL Database
# ------------------------------------------------------------------------------

resource "google_sql_database" "openclaw" {
  name      = var.database_name
  project   = var.project_id
  instance  = google_sql_database_instance.openclaw.name
  charset   = "UTF8"
  collation = "en_US.UTF8"
}

# ------------------------------------------------------------------------------
# Cloud SQL User
# ------------------------------------------------------------------------------

resource "google_sql_user" "openclaw" {
  name      = var.database_user
  project   = var.project_id
  instance  = google_sql_database_instance.openclaw.name
  password  = var.database_password
  deletion_policy = "ABANDON"
}

# ------------------------------------------------------------------------------
# Cloud SQL Read Replica (Optional for Production)
# ------------------------------------------------------------------------------

resource "google_sql_database_instance" "openclaw_replica" {
  count = var.environment == "prod" && var.high_availability ? 1 : 0

  name                 = "${var.instance_name}-replica"
  project              = var.project_id
  region               = var.region
  database_version     = var.database_version
  master_instance_name = google_sql_database_instance.openclaw.name
  replica_configuration {
    failover_target = false
  }

  settings {
    tier              = var.tier
    disk_size         = var.disk_size
    disk_type         = var.disk_type
    availability_type = "ZONAL"

    backup_configuration {
      enabled = false
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network
      require_ssl     = true
    }

    user_labels = var.tags
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# ------------------------------------------------------------------------------
# Cloud SQL Connection Pooler (Optional)
# ------------------------------------------------------------------------------

resource "google_sql_database_instance" "openclaw_pooler" {
  count = var.environment == "prod" ? 1 : 0

  name             = "${var.instance_name}-pooler"
  project          = var.project_id
  region           = var.region
  database_version = var.database_version

  settings {
    tier              = "db-custom-2-7680"
    disk_size         = 20
    disk_type         = "PD_SSD"
    availability_type = "ZONAL"

    ip_configuration {
      ipv4_enabled    = true
      require_ssl     = true
      authorized_networks {
        name  = "gke-pods"
        value = google_compute_subnetwork.secondary_ranges.ip_cidr_range
      }
    }

    user_labels = var.tags
  }
}

# ------------------------------------------------------------------------------
# Secret Manager for Database Credentials
# ------------------------------------------------------------------------------

resource "google_secret_manager_secret" "db_credentials" {
  secret_id = "${var.instance_name}-credentials"
  project   = var.project_id

  labels = var.tags

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_credentials" {
  secret = google_secret_manager_secret.db_credentials.id

  secret_data = jsonencode({
    username   = var.database_user
    password   = var.database_password
    database   = var.database_name
    host       = google_sql_database_instance.openclaw.private_ip_address
    port       = "5432"
    connection_name = google_sql_database_instance.openclaw.connection_name
  })
}

# ------------------------------------------------------------------------------
# Monitoring Alerts
# ------------------------------------------------------------------------------

resource "google_monitoring_alert_policy" "cloud_sql_cpu" {
  count = var.environment == "prod" ? 1 : 0

  display_name = "${var.instance_name} CPU Utilization"
  project      = var.project_id

  conditions {
    display_name = "CPU utilization > 80%"
    condition_threshold {
      filter          = "resource.type = \"cloudsql_database\" AND metric.type = \"cloudsql.googleapis.com/database/cpu/utilization\" AND resource.label.\"database_id\" = \"${google_sql_database_instance.openclaw.connection_name}\""
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

resource "google_monitoring_alert_policy" "cloud_sql_disk" {
  count = var.environment == "prod" ? 1 : 0

  display_name = "${var.instance_name} Disk Space"
  project      = var.project_id

  conditions {
    display_name = "Disk space < 10%"
    condition_threshold {
      filter          = "resource.type = \"cloudsql_database\" AND metric.type = \"cloudsql.googleapis.com/database/disk/bytes_available\" AND resource.label.\"database_id\" = \"${google_sql_database_instance.openclaw.connection_name}\""
      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = var.disk_size * 1024 * 1024 * 1024 * 0.1
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.alert_notification_channels

  severity = "CRITICAL"
}
