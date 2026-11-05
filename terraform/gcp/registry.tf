# ==========================================================================
# Container images: Artifact Registry + keyless GitHub Actions access
#
#   GitHub Actions (main) ──OIDC──▶ Workload Identity Federation
#        └─ impersonates sentra-ci-deployer ──push──▶ Artifact Registry
#   VM ◀── pulls with a short-lived token handed over by the deploy job
#
# No JSON service-account key exists anywhere: GitHub exchanges its own
# OIDC token for a 1-hour Google token, and only for the listed repos on main.
# ==========================================================================

resource "google_project_service" "registry" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "images" {
  location      = var.region
  repository_id = var.name_prefix
  description   = "Sentra container images (built and pushed by GitHub Actions)"
  format        = "DOCKER"

  # Keep the 5 newest versions of each image (rollback room), drop the rest
  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }
  cleanup_policies {
    id     = "delete-old"
    action = "DELETE"
    condition {
      older_than = "604800s" # 7 days; versions kept above are never deleted
    }
  }

  depends_on = [google_project_service.registry]
}

# --------------------------------------------------------------------------
# GitHub Actions identity (Workload Identity Federation, no stored keys)
# --------------------------------------------------------------------------
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "${var.name_prefix}-github"
  display_name              = "GitHub Actions"
  description               = "OIDC identities of the Sentra GitHub repositories"

  depends_on = [google_project_service.registry]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }
  # Only the listed repositories, and only workflows running on main
  attribute_condition = join(" && ", [
    "assertion.repository in ${jsonencode([for r in var.github_repos : "${var.github_owner}/${r}"])}",
    "assertion.ref == 'refs/heads/main'",
  ])

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "ci_deployer" {
  account_id   = "${var.name_prefix}-ci-deployer"
  display_name = "Sentra CI deployer (GitHub Actions)"
  description  = "Pushes and pulls Sentra images. Only usable from GitHub Actions via WIF."

  depends_on = [google_project_service.registry]
}

# Least privilege: write access to this one repository, nothing else
resource "google_artifact_registry_repository_iam_member" "ci_writer" {
  location   = google_artifact_registry_repository.images.location
  repository = google_artifact_registry_repository.images.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.ci_deployer.email}"
}

resource "google_service_account_iam_member" "github_wif" {
  for_each           = toset(var.github_repos)
  service_account_id = google_service_account.ci_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${each.value}"
}
