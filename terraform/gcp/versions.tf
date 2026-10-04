terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 8.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4"
    }
  }

  # State is kept locally (terraform.tfstate, gitignored). For a team setup,
  # move it to a GCS bucket:
  #   backend "gcs" { bucket = "<bucket>" prefix = "sentra/gcp" }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
