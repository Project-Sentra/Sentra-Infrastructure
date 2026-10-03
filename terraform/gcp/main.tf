# ==========================================================================
# Sentra on Google Cloud: a single Compute Engine VM running Docker Compose
# (Caddy + Flask backend + React admin + SentraAI). Supabase stays external.
#
#   Internet ──443/80──▶ [ firewall ] ──▶ VM (Ubuntu 24.04, static IP)
#                                          └─ Caddy → backend / frontend / ai-service
# ==========================================================================

locals {
  web_tag = "${var.name_prefix}-web"
  ssh_tag = "${var.name_prefix}-ssh"
  domain  = var.domain != "" ? var.domain : "${google_compute_address.main.address}.sslip.io"
}

# Make sure the Compute Engine API is on (no-op if already enabled)
resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# --------------------------------------------------------------------------
# Network: dedicated VPC instead of the permissive "default" network
# --------------------------------------------------------------------------
resource "google_compute_network" "main" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "main" {
  name          = "${var.name_prefix}-subnet"
  region        = var.region
  network       = google_compute_network.main.id
  ip_cidr_range = "10.10.0.0/24"

  # VPC flow logs (sampled to keep them within the free logging allowance)
  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Static external IP so the address (and sslip.io name) survives restarts
resource "google_compute_address" "main" {
  name   = "${var.name_prefix}-ip"
  region = var.region

  depends_on = [google_project_service.compute]
}

# --------------------------------------------------------------------------
# Firewall
# --------------------------------------------------------------------------
resource "google_compute_firewall" "web" {
  name          = "${var.name_prefix}-allow-web"
  network       = google_compute_network.main.name
  description   = "HTTP (redirect + ACME) and HTTPS to Caddy"
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [local.web_tag]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  # HTTP/3
  allow {
    protocol = "udp"
    ports    = ["443"]
  }
}

resource "google_compute_firewall" "ssh" {
  name          = "${var.name_prefix}-allow-ssh"
  network       = google_compute_network.main.name
  description   = "SSH for administration and Ansible (key-only)"
  direction     = "INGRESS"
  source_ranges = var.ssh_source_ranges
  target_tags   = [local.ssh_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "icmp" {
  name          = "${var.name_prefix}-allow-icmp"
  network       = google_compute_network.main.name
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [local.web_tag]

  allow {
    protocol = "icmp"
  }
}

# --------------------------------------------------------------------------
# VM
# --------------------------------------------------------------------------
resource "google_compute_instance" "main" {
  name                      = "${var.name_prefix}-server"
  machine_type              = var.machine_type
  zone                      = var.zone
  tags                      = [local.web_tag, local.ssh_tag]
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.main.id

    access_config {
      nat_ip = google_compute_address.main.address
    }
  }

  metadata = {
    # Key-only SSH for the deploy user; ignore project-wide keys
    # (plus the optional CI deploy key used by the GitHub deploy workflows)
    ssh-keys = join("\n", [
      for key in compact([
        trimspace(file(pathexpand(var.ssh_public_key_path))),
        var.ci_deploy_public_key_path == "" ? "" : trimspace(file(pathexpand(var.ci_deploy_public_key_path))),
      ]) : "${var.ssh_user}:${key}"
    ])
    block-project-ssh-keys = "true"
    enable-oslogin         = "FALSE"
  }

  # No service account: Sentra does not call Google APIs, so the VM gets no
  # cloud credentials at all (least privilege).

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  labels = {
    app = "sentra"
  }
}

# --------------------------------------------------------------------------
# Ansible inventory, generated from the real IP (gitignored)
# --------------------------------------------------------------------------
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../../ansible/inventory/hosts.ini"
  file_permission = "0644"
  content         = <<-EOT
    # Generated by Terraform (terraform/gcp). Do not edit by hand.
    [sentra]
    ${google_compute_instance.main.name} ansible_host=${google_compute_address.main.address} ansible_user=${var.ssh_user} ansible_ssh_private_key_file=${pathexpand(var.ssh_private_key_path)}

    [sentra:vars]
    sentra_domain=${local.domain}
  EOT
}
