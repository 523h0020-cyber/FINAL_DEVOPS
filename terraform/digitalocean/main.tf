locals {
  tags = [var.project_name, "terraform", "swarm"]
}

# ─────────────────────────────────────────────────────────────────────────────
# SSH Keypair (auto-generated or pre-existing)
# ─────────────────────────────────────────────────────────────────────────────
resource "tls_private_key" "generated" {
  count     = var.auto_generate_keypair ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "private_key" {
  count           = var.auto_generate_keypair ? 1 : 0
  filename        = var.keypair_output_path
  content         = tls_private_key.generated[0].private_key_pem
  file_permission = "0400"
}

resource "digitalocean_ssh_key" "main" {
  count      = var.auto_generate_keypair ? 1 : 0
  name       = var.ssh_key_name
  public_key = tls_private_key.generated[0].public_key_openssh
}

# ─────────────────────────────────────────────────────────────────────────────
# VPC — private network for Swarm internal traffic
# ─────────────────────────────────────────────────────────────────────────────
resource "digitalocean_vpc" "main" {
  name     = "${var.project_name}-vpc"
  region   = var.region
  ip_range = var.vpc_cidr
}

# ─────────────────────────────────────────────────────────────────────────────
# Firewall — mirrors the AWS Security Group rules exactly
# ─────────────────────────────────────────────────────────────────────────────
resource "digitalocean_firewall" "swarm" {
  name = "${var.project_name}-firewall"

  droplet_ids = concat(
    [digitalocean_droplet.manager.id],
    digitalocean_droplet.workers[*].id
  )

  # ── Inbound ──────────────────────────────────────────────────────────────

  # SSH — restricted to allowed IPs
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.allowed_ssh_ips
  }

  # HTTP — public (Traefik redirect to HTTPS)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # HTTPS — public (Traefik SSL termination)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Swarm cluster management — VPC only
  inbound_rule {
    protocol         = "tcp"
    port_range       = "2377"
    source_addresses = [var.vpc_cidr]
  }

  # Swarm node discovery TCP — VPC only
  inbound_rule {
    protocol         = "tcp"
    port_range       = "7946"
    source_addresses = [var.vpc_cidr]
  }

  # Swarm node discovery UDP — VPC only
  inbound_rule {
    protocol         = "udp"
    port_range       = "7946"
    source_addresses = [var.vpc_cidr]
  }

  # VXLAN overlay network — VPC only
  inbound_rule {
    protocol         = "udp"
    port_range       = "4789"
    source_addresses = [var.vpc_cidr]
  }

  # ── Outbound ─────────────────────────────────────────────────────────────

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Droplets
# ─────────────────────────────────────────────────────────────────────────────
resource "digitalocean_droplet" "manager" {
  name     = "${var.project_name}-manager1"
  region   = var.region
  size     = var.manager_size
  image    = var.image
  vpc_uuid = digitalocean_vpc.main.id
  ssh_keys = var.auto_generate_keypair ? [digitalocean_ssh_key.main[0].fingerprint] : []
  tags     = concat(local.tags, ["manager"])

  depends_on = [digitalocean_ssh_key.main]
}

resource "digitalocean_droplet" "workers" {
  count    = var.worker_count
  name     = "${var.project_name}-worker${count.index + 1}"
  region   = var.region
  size     = var.worker_size
  image    = var.image
  vpc_uuid = digitalocean_vpc.main.id
  ssh_keys = var.auto_generate_keypair ? [digitalocean_ssh_key.main[0].fingerprint] : []
  tags     = concat(local.tags, ["worker"])

  depends_on = [digitalocean_ssh_key.main]
}

# ─────────────────────────────────────────────────────────────────────────────
# Reserved IP — static public IP for manager (replaces AWS Elastic IP)
# ─────────────────────────────────────────────────────────────────────────────
resource "digitalocean_reserved_ip" "manager" {
  region = var.region
}

resource "digitalocean_reserved_ip_assignment" "manager" {
  ip_address = digitalocean_reserved_ip.manager.ip_address
  droplet_id = digitalocean_droplet.manager.id
}

# ─────────────────────────────────────────────────────────────────────────────
# DigitalOcean Project — groups all resources
# ─────────────────────────────────────────────────────────────────────────────
resource "digitalocean_project" "main" {
  name        = var.project_name
  description = "Final DevOps Tier 4 Docker Swarm"
  purpose     = "Web Application"
  environment = "Production"

  resources = concat(
    [
      digitalocean_droplet.manager.urn,
    ],
    digitalocean_droplet.workers[*].urn
  )
}
