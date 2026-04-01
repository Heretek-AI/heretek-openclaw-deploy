# ==============================================================================
# Heretek OpenClaw - GCP VPC Configuration
# ==============================================================================
# VPC network module for OpenClaw infrastructure
# ==============================================================================

# ------------------------------------------------------------------------------
# VPC Network
# ------------------------------------------------------------------------------

resource "google_compute_network" "openclaw" {
  name                            = var.network_name
  project                         = var.project_id
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = false

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Subnets
# ------------------------------------------------------------------------------

resource "google_compute_subnetwork" "openclaw" {
  count = length(var.subnets)

  name                     = var.subnets[count.index].name
  project                  = var.project_id
  region                   = var.subnets[count.index].region
  network                  = google_compute_network.openclaw.id
  ip_cidr_range            = var.subnets[count.index].ip_cidr_range
  private_ip_google_access = var.enable_private_google_access

  dynamic "log_config" {
    for_each = var.enable_vpc_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Firewall Rules
# ------------------------------------------------------------------------------

# Allow internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.network_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.openclaw.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.vpc_cidr,
  ]

  tags = var.tags
}

# Allow health checks from Google Cloud health check systems
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.network_name}-allow-health-checks"
  project = var.project_id
  network = google_compute_network.openclaw.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22",
  ]

  target_tags = ["openclaw"]

  tags = var.tags
}

# Allow IAP (Identity-Aware Proxy) connections
resource "google_compute_firewall" "allow_iap" {
  name    = "${var.network_name}-allow-iap"
  project = var.project_id
  network = google_compute_network.openclaw.name

  allow {
    protocol = "tcp"
    ports    = ["22", "3389", "443"]
  }

  source_ranges = [
    "35.235.240.0/20",
  ]

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Cloud NAT
# ------------------------------------------------------------------------------

resource "google_compute_router" "openclaw" {
  count = length(var.subnets)

  name    = "${var.network_name}-router-${var.subnets[count.index].region}"
  project = var.project_id
  region  = var.subnets[count.index].region
  network = google_compute_network.openclaw.id

  tags = var.tags
}

resource "google_compute_router_nat" "openclaw" {
  count = length(var.subnets)

  name                               = "${var.network_name}-nat-${var.subnets[count.index].region}"
  project                            = var.project_id
  router                             = google_compute_router.openclaw[count.index].name
  region                             = var.subnets[count.index].region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Private Service Connection (for Cloud SQL, Memorystore)
# ------------------------------------------------------------------------------

resource "google_compute_global_address" "private_ip_alloc" {
  name          = "${var.network_name}-private-ip-alloc"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.openclaw.id

  labels = var.tags
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.openclaw.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]

  deletion_policy = "ABANDON"
}

# ------------------------------------------------------------------------------
# Routes (if needed)
# ------------------------------------------------------------------------------

# Default route to internet via NAT
resource "google_compute_route" "default_internet" {
  name    = "${var.network_name}-default-internet"
  project = var.project_id
  network = google_compute_network.openclaw.name

  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"

  tags = var.tags
}
