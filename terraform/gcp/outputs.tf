output "vpc_name" {
  description = "Created VPC network name."
  value       = google_compute_network.main.name
}

output "public_subnet_id" {
  description = "Public subnet self link."
  value       = google_compute_subnetwork.public.id
}

output "private_subnet_id" {
  description = "Private subnet self link."
  value       = google_compute_subnetwork.private.id
}

output "firewall_name" {
  description = "Firewall that only allows 22/80/443 inbound."
  value       = google_compute_firewall.allow_web_ssh.name
}

output "swarm_instance_names" {
  description = "Compute instance names for Docker Swarm mode."
  value       = local.is_swarm ? google_compute_instance.swarm_nodes[*].name : []
}

output "swarm_public_ips" {
  description = "Public IPs for Docker Swarm nodes."
  value       = local.is_swarm ? [for n in google_compute_instance.swarm_nodes : n.network_interface[0].access_config[0].nat_ip] : []
}

output "gke_cluster_name" {
  description = "GKE cluster name when deployment_mode is kubernetes."
  value       = local.is_k8s ? google_container_cluster.this[0].name : null
}
