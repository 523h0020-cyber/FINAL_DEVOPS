provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

locals {
  is_swarm = var.deployment_mode == "swarm"
  is_k8s   = var.deployment_mode == "kubernetes"

  labels = {
    project    = var.project_name
    managed_by = "terraform"
  }

  gke_sa_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter"
  ]
}

resource "google_compute_network" "main" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public" {
  name          = "${var.project_name}-public-subnet"
  ip_cidr_range = var.public_subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id
}

resource "google_compute_subnetwork" "private" {
  name                     = "${var.project_name}-private-subnet"
  ip_cidr_range            = var.private_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.main.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_secondary_range
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_secondary_range
  }
}

resource "google_compute_firewall" "allow_web_ssh" {
  name      = "${var.project_name}-allow-web-ssh"
  network   = google_compute_network.main.name
  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-edge"]

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }
}

resource "google_compute_router" "nat_router" {
  name    = "${var.project_name}-router"
  network = google_compute_network.main.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.project_name}-nat"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_instance" "swarm_nodes" {
  count = local.is_swarm ? 3 : 0

  name         = "${var.project_name}-swarm-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["web-edge", "swarm"]

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public.id
    access_config {}
  }

  labels = merge(local.labels, {
    role = count.index == 0 ? "manager" : "worker"
  })
}

resource "google_service_account" "gke_nodes" {
  count = local.is_k8s ? 1 : 0

  account_id   = "${replace(var.project_name, "-", "")}-gkenodes"
  display_name = "${var.project_name} GKE Nodes"
}

resource "google_project_iam_member" "gke_sa_roles" {
  for_each = local.is_k8s ? toset(local.gke_sa_roles) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes[0].email}"
}

resource "google_container_cluster" "this" {
  count = local.is_k8s ? 1 : 0

  name                     = "${var.project_name}-gke"
  location                 = var.region
  network                  = google_compute_network.main.id
  subnetwork               = google_compute_subnetwork.private.id
  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
}

resource "google_container_node_pool" "primary" {
  count = local.is_k8s ? 1 : 0

  name     = "${var.project_name}-node-pool"
  location = var.region
  cluster  = google_container_cluster.this[0].name

  node_count = var.gke_node_count

  node_config {
    machine_type    = var.gke_node_machine_type
    service_account = google_service_account.gke_nodes[0].email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    tags            = ["web-edge"]
    labels          = local.labels
  }

  depends_on = [google_project_iam_member.gke_sa_roles]
}
