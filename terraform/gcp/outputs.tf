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
