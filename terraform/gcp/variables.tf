variable "project_name" {
  description = "Project name prefix used in resource naming."
  type        = string
  default     = "final-tier4"
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for regional resources."
  type        = string
  default     = "asia-southeast1"
}

variable "zone" {
  description = "GCP zone for zonal resources (swarm mode)."
  type        = string
  default     = "asia-southeast1-a"
}

variable "deployment_mode" {
  description = "Target orchestrator: swarm or kubernetes."
  type        = string
  default     = "swarm"

  validation {
    condition     = contains(["swarm", "kubernetes"], var.deployment_mode)
    error_message = "deployment_mode must be either swarm or kubernetes."
  }
}

variable "vpc_name" {
  description = "Custom VPC network name."
  type        = string
  default     = "final-tier4-vpc"
}

variable "public_subnet_cidr" {
  description = "CIDR for the public subnet."
  type        = string
  default     = "10.20.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR for the private subnet."
  type        = string
  default     = "10.20.10.0/24"
}

variable "pods_secondary_range" {
  description = "Secondary CIDR range for Kubernetes pods."
  type        = string
  default     = "10.20.20.0/20"
}

variable "services_secondary_range" {
  description = "Secondary CIDR range for Kubernetes services."
  type        = string
  default     = "10.20.40.0/24"
}

variable "machine_type" {
  description = "Machine type for Docker Swarm nodes."
  type        = string
  default     = "e2-medium"
}

variable "gke_node_count" {
  description = "Node count for GKE node pool."
  type        = number
  default     = 2
}

variable "gke_node_machine_type" {
  description = "Machine type for GKE node pool."
  type        = string
  default     = "e2-standard-2"
}
