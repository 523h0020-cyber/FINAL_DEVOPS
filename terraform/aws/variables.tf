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
  description = "Target orchestrator. Tier 4 uses Docker Swarm only."
  type        = string
  default     = "swarm"

  validation {
    condition     = var.deployment_mode == "swarm"
    error_message = "Tier 4 in this project supports Docker Swarm only."
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
  # Khá»›p vá»›i SSH_KEY="$TERRAFORM_DIR/final-devops-key.pem" trong auto-fix.sh
  default     = "./final-devops-key.pem"
}

