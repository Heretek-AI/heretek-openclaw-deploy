# ==============================================================================
# Heretek OpenClaw - GCP Artifact Registry Configuration
# ==============================================================================
# Artifact Registry for OpenClaw container images
# ==============================================================================

# ------------------------------------------------------------------------------
# Artifact Registry Repository
# ------------------------------------------------------------------------------

resource "google_artifact_registry_repository" "openclaw" {
  location      = var.location
  repository_id = var.repository_name
  project       = var.project_id
  format        = var.format
  description   = "Artifact Registry for Heretek OpenClaw container images"

  # Cleanup policy
  dynamic "cleanup_policy" {
    for_each = var.cleanup_policy_days > 0 ? [1] : []
    content {
      id     = "expire-old-images"
      action = "DELETE"
      condition {
        tag_state    = "UNTAGGED"
        older_than   = "${var.cleanup_policy_days}d"
      }
    }
  }

  # Cleanup policy for tagged images
  dynamic "cleanup_policy" {
    for_each = var.cleanup_policy_days > 0 ? [1] : []
    content {
      id     = "keep-recent-tagged"
      action = "DELETE"
      condition {
        tag_prefixes = ["latest", "main"]
        count        = 10
      }
    }
  }

  # Maven configuration (if needed)
  maven_config {
    version_policy = "VERSION_POLICY_RELEASE"
  }

  labels = var.tags
}

# ------------------------------------------------------------------------------
# IAM Permissions
# ------------------------------------------------------------------------------

resource "google_artifact_registry_repository_iam_member" "openclaw_reader" {
  project    = var.project_id
  location   = var.location
  repository = google_artifact_registry_repository.openclaw.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.project_id}.svc.id.goog[openclaw/openclaw-sa]"
}

resource "google_artifact_registry_repository_iam_member" "openclaw_writer" {
  project    = var.project_id
  location   = var.location
  repository = google_artifact_registry_repository.openclaw.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-artifactregistry.iam.gserviceaccount.com"
}

# ------------------------------------------------------------------------------
# Remote Repository (for caching external images)
# ------------------------------------------------------------------------------

resource "google_artifact_registry_repository" "docker_hub_cache" {
  count = var.environment == "prod" ? 1 : 0

  location      = var.location
  repository_id = "${var.repository_name}-docker-hub-cache"
  project       = var.project_id
  format        = "DOCKER"
  description   = "Docker Hub cache for OpenClaw"

  mode = "REMOTE_REPOSITORY"
  remote_repository_config {
    description = "Docker Hub remote repository"
    dockerhub_repository {}
  }

  cleanup_policy_dry_run = false

  labels = var.tags
}

resource "google_artifact_registry_repository" "ghcr_cache" {
  count = var.environment == "prod" ? 1 : 0

  location      = var.location
  repository_id = "${var.repository_name}-ghcr-cache"
  project       = var.project_id
  format        = "DOCKER"
  description   = "GitHub Container Registry cache for OpenClaw"

  mode = "REMOTE_REPOSITORY"
  remote_repository_config {
    description = "GitHub Container Registry remote repository"
    docker_repository {
      custom_repository {
        uri = "ghcr.io"
      }
    }
  }

  cleanup_policy_dry_run = false

  labels = var.tags
}

# ------------------------------------------------------------------------------
# Virtual Repository (for unified access)
# ------------------------------------------------------------------------------

resource "google_artifact_registry_repository" "openclaw_virtual" {
  count = var.environment == "prod" ? 1 : 0

  location      = var.location
  repository_id = "${var.repository_name}-virtual"
  project       = var.project_id
  format        = "DOCKER"
  description   = "Virtual repository for OpenClaw"

  mode = "VIRTUAL_REPOSITORY"
  virtual_repository_config {
    upstream_policies {
      id        = "upstream-docker-hub"
      repository_id = google_artifact_registry_repository.docker_hub_cache[0].repository_id
      priority  = 1
    }
    upstream_policies {
      id        = "upstream-ghcr"
      repository_id = google_artifact_registry_repository.ghcr_cache[0].repository_id
      priority  = 2
    }
    upstream_policies {
      id        = "upstream-local"
      repository_id = google_artifact_registry_repository.openclaw.repository_id
      priority  = 3
    }
  }

  labels = var.tags
}

# ------------------------------------------------------------------------------
# KMS Key for Encryption (Optional)
# ------------------------------------------------------------------------------

resource "google_kms_key_ring" "artifact_registry" {
  count = var.environment == "prod" ? 1 : 0

  name     = "${var.repository_name}-keyring"
  project  = var.project_id
  location = var.location

  labels = var.tags
}

resource "google_kms_crypto_key" "artifact_registry" {
  count = var.environment == "prod" ? 1 : 0

  name     = "${var.repository_name}-key"
  key_ring = google_kms_key_ring.artifact_registry[0].id
  purpose  = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = false
  }

  labels = var.tags
}
