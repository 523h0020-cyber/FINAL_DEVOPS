variable "project_name" {
  description = "Project name prefix used in resource naming."
  type        = string
  default     = "final-tier4"
}

variable "region" {
  description = "AWS region for deployment."
  type        = string
  default     = "us-east-1"
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

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for Docker Swarm nodes."
  type        = string
  default     = "t3.small"
}

variable "ssh_key_name" {
  description = "EC2 Key Pair name. If not provided, Terraform will auto-generate one."
  type        = string
  default     = "final-devops-key"
}

variable "auto_generate_keypair" {
  description = "Auto-generate keypair in Terraform if true. Set to false if you already have one in AWS."
  type        = bool
  default     = true
}

variable "keypair_output_path" {
  description = "Path where private key will be saved. Relative to terraform/aws/ directory."
  type        = string
  # ./final-devops-key.pem = terraform/aws/final-devops-key.pem
  # Khớp với SSH_KEY="$TERRAFORM_DIR/final-devops-key.pem" trong auto-fix.sh
  default = "./final-devops-key.pem"
}

variable "k8s_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.29"
}

variable "k8s_node_instance_types" {
  description = "Instance types for EKS managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "k8s_desired_nodes" {
  description = "Desired node count for EKS managed node group."
  type        = number
  default     = 2
}

variable "k8s_min_nodes" {
  description = "Minimum node count for EKS managed node group."
  type        = number
  default     = 1
}

variable "k8s_max_nodes" {
  description = "Maximum node count for EKS managed node group."
  type        = number
  default     = 4
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to Swarm nodes."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.allowed_ssh_cidrs) > 0
    error_message = "Set allowed_ssh_cidrs to your trusted public IP, for example [\"x.x.x.x/32\"]."
  }
}
