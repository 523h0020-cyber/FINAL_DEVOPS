# AWS Terraform (Tier 4)

This stack creates:

- 1 VPC
- Public/Private subnets
- Security group that allows only TCP 22, 80, 443 inbound
- `deployment_mode = "swarm"`: 3 EC2 instances for Docker Swarm
- `deployment_mode = "kubernetes"`: EKS cluster + managed node group

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and edit values.
2. Run:

```bash
terraform init
terraform plan
terraform apply
```

Terraform is declarative, so repeated `apply` runs are idempotent and only reconcile drift.
