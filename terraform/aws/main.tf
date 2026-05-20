provider "aws" {
  region = var.region
}

locals {
  is_swarm   = var.deployment_mode == "swarm"
  edge_ports = [22, 80, 443]

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# Auto-generate SSH Keypair (Optional, based on auto_generate_keypair)
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
resource "tls_private_key" "generated" {
  count     = var.auto_generate_keypair ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated" {
  count           = var.auto_generate_keypair ? 1 : 0
  key_name        = var.ssh_key_name
  public_key      = tls_private_key.generated[0].public_key_openssh

  tags = merge(local.tags, {
    Name = "${var.project_name}-keypair"
  })

  lifecycle {
    ignore_changes = [public_key]
  }
}

# local_sensitive_file tá»± Ä‘á»™ng áº©n ná»™i dung key khá»i logs vÃ  Ä‘áº·t permission 0600
# Thay tháº¿ local_file vÃ¬ sensitive_content=true khÃ´ng há»£p lá»‡ trong local provider v2+
resource "local_sensitive_file" "private_key" {
  count           = var.auto_generate_keypair ? 1 : 0
  filename        = var.keypair_output_path
  content         = tls_private_key.generated[0].private_key_pem
  file_permission = "0400"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "${var.project_name}-igw"
  })
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = "${var.region}${count.index == 0 ? "a" : "b"}"
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${var.project_name}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = "${var.region}${count.index == 0 ? "a" : "b"}"
  map_public_ip_on_launch = false

  tags = merge(local.tags, {
    Name = "${var.project_name}-private-${count.index + 1}"
    Tier = "private"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.tags, {
    Name = "${var.project_name}-nat-eip"
  })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.tags, {
    Name = "${var.project_name}-nat"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "edge" {
  name        = "${var.project_name}-edge-sg"
  description = "Allow only 22, 80, 443"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = local.edge_ports
    content {
      description = "Allow TCP ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # â”€â”€ Docker Swarm internal communication (self-referencing) â”€â”€
  ingress {
    description     = "Swarm cluster management"
    from_port       = 2377
    to_port         = 2377
    protocol        = "tcp"
    self            = true
  }

  ingress {
    description     = "Swarm node discovery (TCP)"
    from_port       = 7946
    to_port         = 7946
    protocol        = "tcp"
    self            = true
  }

  ingress {
    description     = "Swarm node discovery (UDP)"
    from_port       = 7946
    to_port         = 7946
    protocol        = "udp"
    self            = true
  }

  ingress {
    description     = "VXLAN overlay network"
    from_port       = 4789
    to_port         = 4789
    protocol        = "udp"
    self            = true
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-edge-sg"
  })
}

resource "aws_instance" "swarm_nodes" {
  count = local.is_swarm ? 3 : 0

  ami                         = "ami-0fc5d935ebf8bc3bc" # Ubuntu 22.04 LTS (us-east-1)
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[count.index % length(aws_subnet.public)].id
  vpc_security_group_ids      = [aws_security_group.edge.id]
  associate_public_ip_address = true
  key_name                    = var.ssh_key_name

  # Äáº£m báº£o Key Pair Ä‘Ã£ Ä‘Æ°á»£c upload lÃªn AWS trÆ°á»›c khi táº¡o EC2
  # TrÃ¡nh lá»—i InvalidKeyPair.NotFound khi auto_generate_keypair = true
  depends_on = [aws_key_pair.generated]

  tags = merge(local.tags, {
    Name = "${var.project_name}-swarm-${count.index + 1}"
    Role = count.index == 0 ? "manager" : "worker"
  })
}

