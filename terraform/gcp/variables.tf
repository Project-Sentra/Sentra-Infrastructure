variable "project_id" {
  description = "GCP project ID (e.g. sentra-parking-510509)"
  type        = string
}

variable "region" {
  description = "GCP region. asia-south1 = Mumbai (closest to Sri Lanka)"
  type        = string
  default     = "asia-south1"
}

variable "zone" {
  description = "GCP zone inside the region"
  type        = string
  default     = "asia-south1-a"
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "sentra"
}

variable "machine_type" {
  description = "VM size. e2-standard-2 = 2 vCPU / 8 GB, enough for backend + frontend + AI (PyTorch/EasyOCR)"
  type        = string
  default     = "e2-standard-2"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB (Docker images incl. PyTorch need ~15 GB)"
  type        = number
  default     = 40
}

variable "ssh_user" {
  description = "Linux user created on the VM for SSH/Ansible"
  type        = string
  default     = "sentra"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key allowed to log in"
  type        = string
  default     = "~/.ssh/sentra_gcp.pub"
}

variable "ssh_private_key_path" {
  description = "Path to the matching SSH private key (only written into the Ansible inventory)"
  type        = string
  default     = "~/.ssh/sentra_gcp"
}

variable "ssh_source_ranges" {
  description = "CIDR ranges allowed to SSH. Use [\"<your-ip>/32\"] for best security (find it with: curl -4 ifconfig.me)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "domain" {
  description = "Public domain for HTTPS. Leave empty to use the free <ip>.sslip.io name (no DNS setup needed)"
  type        = string
  default     = ""
}
