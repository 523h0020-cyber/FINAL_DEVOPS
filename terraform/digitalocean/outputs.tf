output "manager_reserved_ip" {
  description = "Static public IP of the Swarm manager (point DNS here)."
  value       = digitalocean_reserved_ip.manager.ip_address
}

output "manager_droplet_ip" {
  description = "Ephemeral public IP of the manager Droplet."
  value       = digitalocean_droplet.manager.ipv4_address
}

output "manager_private_ip" {
  description = "Private VPC IP of the manager Droplet."
  value       = digitalocean_droplet.manager.ipv4_address_private
}

output "worker_public_ips" {
  description = "Public IPs of all worker Droplets."
  value       = digitalocean_droplet.workers[*].ipv4_address
}

output "worker_private_ips" {
  description = "Private VPC IPs of all worker Droplets."
  value       = digitalocean_droplet.workers[*].ipv4_address_private
}

output "vpc_id" {
  description = "DigitalOcean VPC UUID."
  value       = digitalocean_vpc.main.id
}

output "firewall_id" {
  description = "DigitalOcean Firewall ID."
  value       = digitalocean_firewall.swarm.id
}

output "ssh_key_fingerprint" {
  description = "Fingerprint of the uploaded SSH key."
  value       = var.auto_generate_keypair ? digitalocean_ssh_key.main[0].fingerprint : "pre-existing"
}
