output "vpc_id" {
  description = "Created VPC ID."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = aws_subnet.private[*].id
}

output "edge_security_group_id" {
  description = "Security group that only allows 22/80/443 inbound."
  value       = aws_security_group.edge.id
}

output "swarm_instance_ids" {
  description = "EC2 instance IDs for Docker Swarm mode."
  value       = local.is_swarm ? aws_instance.swarm_nodes[*].id : []
}

output "swarm_public_ips" {
  description = "Public IPs for Docker Swarm nodes."
  value       = local.is_swarm ? aws_instance.swarm_nodes[*].public_ip : []
}

output "eks_cluster_name" {
  description = "EKS cluster name when deployment_mode is kubernetes."
  value       = local.is_k8s ? aws_eks_cluster.this[0].name : null
}

output "swarm_manager_elastic_ip" {
  description = "Static Elastic IP attached to the Swarm manager / Traefik entrypoint."
  value       = local.is_swarm ? aws_eip.swarm_manager[0].public_ip : null
}
