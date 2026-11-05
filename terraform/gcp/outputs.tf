output "external_ip" {
  description = "Static public IP of the Sentra VM"
  value       = google_compute_address.main.address
}

output "domain" {
  description = "Domain Caddy will request an HTTPS certificate for"
  value       = local.domain
}

output "url" {
  description = "Admin dashboard URL (after Ansible deploys the app)"
  value       = "https://${local.domain}"
}

output "ssh_command" {
  description = "SSH into the VM"
  value       = "ssh -i ${var.ssh_private_key_path} ${var.ssh_user}@${google_compute_address.main.address}"
}

output "next_step" {
  description = "What to run next"
  value       = "cd ../../ansible && ansible-playbook site.yml --ask-vault-pass"
}

output "image_registry" {
  description = "Docker registry path for Sentra images"
  value       = "${google_artifact_registry_repository.images.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}

output "github_wif_provider" {
  description = "Workload Identity provider for google-github-actions/auth"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "ci_service_account" {
  description = "Service account the GitHub deploy workflows impersonate"
  value       = google_service_account.ci_deployer.email
}
