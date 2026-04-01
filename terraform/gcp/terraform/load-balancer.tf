# ==============================================================================
# Heretek OpenClaw - GCP Cloud Load Balancing Configuration
# ==============================================================================
# Cloud Load Balancing for OpenClaw traffic routing
# ==============================================================================

# ------------------------------------------------------------------------------
# Serverless Network Endpoint Group (for GKE)
# ------------------------------------------------------------------------------

resource "google_compute_network_endpoint_group" "gateway_neg" {
  name                  = "${var.name}-gateway-neg"
  project               = var.project_id
  network_endpoint_type = "GCE_VM_IP_PORT"
  network               = var.network
  subnetwork            = var.subnet
  region                = var.region

  dynamic "network_endpoint" {
    for_each = []  # Populated by Kubernetes service
    content {
      instance = network_endpoint.value.instance
      port     = network_endpoint.value.port
    }
  }

  labels = var.tags
}

resource "google_compute_network_endpoint_group" "litellm_neg" {
  name                  = "${var.name}-litellm-neg"
  project               = var.project_id
  network_endpoint_type = "GCE_VM_IP_PORT"
  network               = var.network
  subnetwork            = var.subnet
  region                = var.region

  labels = var.tags
}

# ------------------------------------------------------------------------------
# Health Checks
# ------------------------------------------------------------------------------

resource "google_compute_health_check" "gateway" {
  name   = "${var.name}-gateway-health"
  project = var.project_id

  timeout_sec        = 5
  check_interval_sec = 10
  healthy_threshold  = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 18789
    request_path = "/health"
  }
}

resource "google_compute_health_check" "litellm" {
  name   = "${var.name}-litellm-health"
  project = var.project_id

  timeout_sec        = 5
  check_interval_sec = 10
  healthy_threshold  = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 4000
    request_path = "/health"
  }
}

# ------------------------------------------------------------------------------
# Backend Services
# ------------------------------------------------------------------------------

resource "google_compute_backend_service" "gateway" {
  name        = "${var.name}-gateway"
  project     = var.project_id
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  health_checks = [google_compute_health_check.gateway.id]

  load_balancing_scheme = "EXTERNAL_MANAGED"

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  labels = var.tags
}

resource "google_compute_backend_service" "litellm" {
  name        = "${var.name}-litellm"
  project     = var.project_id
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 60

  health_checks = [google_compute_health_check.litellm.id]

  load_balancing_scheme = "EXTERNAL_MANAGED"

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  labels = var.tags
}

# ------------------------------------------------------------------------------
# URL Map
# ------------------------------------------------------------------------------

resource "google_compute_url_map" "openclaw" {
  name    = "${var.name}-url-map"
  project = var.project_id

  default_service = google_compute_backend_service.gateway.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "all-paths"
  }

  path_matcher {
    name            = "all-paths"
    default_service = google_compute_backend_service.gateway.id

    path_rule {
      paths   = ["/v1/*", "/litellm/*"]
      service = google_compute_backend_service.litellm.id
    }

    path_rule {
      paths   = ["/ws/*", "/gateway/*"]
      service = google_compute_backend_service.gateway.id
    }
  }
}

# ------------------------------------------------------------------------------
# Target HTTP Proxy (Redirect to HTTPS)
# ------------------------------------------------------------------------------

resource "google_compute_target_http_proxy" "openclaw" {
  name    = "${var.name}-http-proxy"
  project = var.project_id

  url_map = google_compute_url_map.openclaw.id
}

# ------------------------------------------------------------------------------
# Target HTTPS Proxy
# ------------------------------------------------------------------------------

resource "google_compute_target_https_proxy" "openclaw" {
  name    = "${var.name}-https-proxy"
  project = var.project_id

  url_map            = google_compute_url_map.openclaw.id
  ssl_certificates   = [google_compute_managed_ssl_certificate.openclaw[0].id]
  ssl_policy         = google_compute_ssl_policy.openclaw[0].id
}

# ------------------------------------------------------------------------------
# Managed SSL Certificate
# ------------------------------------------------------------------------------

resource "google_compute_managed_ssl_certificate" "openclaw" {
  count = var.ssl_certificate_arn == null && var.managed_domain != null ? 1 : 0

  name    = "${var.name}-ssl-cert"
  project = var.project_id

  managed {
    domains = [var.managed_domain]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# SSL Policy
# ------------------------------------------------------------------------------

resource "google_compute_ssl_policy" "openclaw" {
  count = var.ssl_certificate_arn == null ? 1 : 0

  name    = "${var.name}-ssl-policy"
  project = var.project_id

  min_tls_version   = "TLS_1_2"
  profile           = "MODERN"
  custom_features   = []
}

# ------------------------------------------------------------------------------
# Global Forwarding Rules
# ------------------------------------------------------------------------------

resource "google_compute_global_forwarding_rule" "http" {
  name       = "${var.name}-http-fr"
  project    = var.project_id
  ip_protocol = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range = "80"
  target     = google_compute_target_http_proxy.openclaw.id
  ip_address = google_compute_global_address.openclaw[0].address
}

resource "google_compute_global_forwarding_rule" "https" {
  name       = "${var.name}-https-fr"
  project    = var.project_id
  ip_protocol = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range = "443"
  target     = google_compute_target_https_proxy.openclaw.id
  ip_address = google_compute_global_address.openclaw[0].address
}

# ------------------------------------------------------------------------------
# Global Static IP Address
# ------------------------------------------------------------------------------

resource "google_compute_global_address" "openclaw" {
  count = var.load_balancer_ip == null ? 1 : 0

  name         = "${var.name}-ip"
  project      = var.project_id
  ip_version   = "IPV4"
}

# ------------------------------------------------------------------------------
# HTTP to HTTPS Redirect
# ------------------------------------------------------------------------------

resource "google_compute_url_map" "http_redirect" {
  name    = "${var.name}-http-redirect"
  project = var.project_id

  default_url_redirect {
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
    https_redirect         = true
  }
}
