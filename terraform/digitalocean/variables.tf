variable "do_token" {
  description = "DigitalOcean API token. Set via TF_VAR_do_token or .env."
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Project name prefix used in resource naming."
  type        = string
  default     = "final-tier4"
}

variable "region" {
  description = "DigitalOcean region slug."
  type        = string
  default     = "sgp1"
}

variable "manager_size" {
  description = "Droplet size for the Swarm manager node."
  type        = string
  default     = "s-1vcpu-2gb"
}

variable "worker_size" {
  description = "Droplet size for Swarm worker nodes."
  type        = string
  default     = "s-1vcpu-1gb"
}

variable "worker_count" {
  description = "Number of worker Droplets."
  type        = number
  default     = 2
}

variable "image" {
  description = "Droplet base image slug."
  type        = string
  default     = "ubuntu-22-04-x64"
}

variable "ssh_key_name" {
  description = "Name for the SSH key resource in DigitalOcean."
  type        = string
  default     = "final-devops-key"
}

variable "auto_generate_keypair" {
  description = "Auto-generate SSH keypair in Terraform. Set false if you already have a key in DigitalOcean."
  type        = bool
  default     = true
}

variable "keypair_output_path" {
  description = "Local path where the generated private key will be saved."
  type        = string
  default     = "./final-devops-key.pem"
}

variable "vpc_cidr" {
  description = "Private VPC CIDR for internal Swarm communication."
  type        = string
  default     = "10.10.0.0/16"
}

variable "allowed_ssh_ips" {
  description = "List of IPs allowed to SSH (port 22). Use your own IP."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.allowed_ssh_ips) > 0
    error_message = "Set allowed_ssh_ips to your public IP CIDR, for example [\"1.2.3.4/32\"]."
  }
}

