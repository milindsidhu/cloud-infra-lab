
# 1) VPC + subnet
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "gke_subnet" {
  name          = "${var.network_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  network       = google_compute_network.vpc.id
  region        = var.region
  private_ip_google_access = true
}

# 2) Router and Cloud NAT (so private nodes can reach internet for upgrades, pulls)
resource "google_compute_router" "nat_router" {
  name    = "${var.network_name}-router"
  network = google_compute_network.vpc.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name                       = "${var.network_name}-nat"
  router                     = google_compute_router.nat_router.name
  region                     = var.region
  nat_ip_allocate_option     = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# 3) Optional node service account
resource "google_service_account" "node_sa" {
  count       = var.node_service_account == "" ? 1 : 0
  account_id  = "gke-node-sa-${substr(md5(var.cluster_name),0,6)}"
  display_name = "GKE nodes service account"
}

locals {
  node_sa_email = var.node_service_account != "" ? var.node_service_account : (length(google_service_account.node_sa) > 0 ? google_service_account.node_sa[0].email : "")
}

# Give node SA minimal roles commonly required (you may harden later)
# resource "google_project_iam_member" "node_sa_container_runtime" {
#   count  = local.node_sa_email != "" ? 1 : 0
#   project = var.project_id
#   role   = "roles/container.nodeServiceAccount"
#   member = "serviceAccount:${local.node_sa_email}"
# }

# 4) GKE private cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1

  networking_mode = "VPC_NATIVE"
  network         = google_compute_network.vpc.id
  subnetwork      = google_compute_subnetwork.gke_subnet.name

  deletion_protection = false 

  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # master_authorized_networks_config {
  #   dynamic "cidr_blocks" {
  #     for_each = var.authorized_networks
  #     content {
  #       cidr_block   = cidr_blocks.value.cidr
  #       display_name = cidr_blocks.value.description
  #     }
  #   }
  # }

  # Always define master_authorized_networks_config when private endpoint is enabled
  dynamic "master_authorized_networks_config" {
    for_each = [1] # ensure the block always exists

    content {
      dynamic "cidr_blocks" {
        for_each = var.enable_private_endpoint ? [] : var.authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr
          display_name = cidr_blocks.value.description
        }
      }
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    # kubernetes_dashboard {
    #   disabled = true
    # }
  }

  ip_allocation_policy {
    # use_ip_aliases = true
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # keep master authorized networks and private endpoint settings as per variables
}

# 5) Node pool
# resource "google_container_node_pool" "primary_nodes" {
#   name       = "primary-pool"
#   project    = var.project_id
#   location   = var.region
#   cluster    = google_container_cluster.primary.name

#   node_config {
#     machine_type = var.machine_type
#     service_account = local.node_sa_email

#     disk_size_gb = "30"
#     disk_type    = "pd-standard"

#     oauth_scopes = [
#       "https://www.googleapis.com/auth/cloud-platform",
#     ]
#   }

#   autoscaling {
#     min_node_count = 1
#     # max_node_count = max(1, var.node_count * 2)
#     max_node_count = 3
#   }

#   initial_node_count = var.node_count
#   management {
#     auto_repair  = true
#     auto_upgrade = true
#   }
# }

resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-pool"
  project    = var.project_id
  location   = var.region
  cluster    = google_container_cluster.primary.name

  node_config {
    boot_disk {
      size_gb = 30
      disk_type    = "pd-standard"
    }
    machine_type    = var.machine_type
    service_account = local.node_sa_email

    disk_size_gb = 30             # number, not string
    disk_type    = "pd-standard"  # explicitly set standard disk

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      env  = "dev"
      team = "platform"
    }
  }

  lifecycle {
    precondition {
      condition     = contains(keys(var.node_labels), "env") && contains(keys(var.node_labels), "team")
      error_message = "Node labels MUST include: env + team."
    }
  }
  
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  initial_node_count = var.node_count
  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Firewall for jumpbox
resource "google_compute_firewall" "jumpbox_fw" {
  name    = "${var.cluster_name}-jumpbox-fw"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["jumpbox"]
}

# Jumpbox VM (Debian + NGINX install in startup script)
resource "google_compute_instance" "jumpbox" {
  name         = "${var.cluster_name}-jumpbox"
  machine_type = "e2-micro"
  zone         = "${var.region}-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size      = 20            # smaller than 100 GB
      type      = "pd-standard"
    }
  }

  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.gke_subnet.id
    access_config {} # Assign public IP
  }

  tags = ["jumpbox"]

  metadata = {
    ssh-keys = "milindsidhu:${file(var.ssh_public_key_path)}"
    startup-script = <<-EOT
      #!/bin/bash
      apt-get update -y
      apt-get install -y nginx

      cat > /etc/nginx/sites-enabled/reverse-proxy.conf <<EOF
      server {
        listen 80;
        location / {
          proxy_pass http://${google_container_cluster.primary.private_cluster_config[0].private_endpoint};
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
        }
      }
      EOF

      systemctl restart nginx
    EOT
  }

  depends_on = [
    google_container_cluster.primary,
    google_compute_firewall.jumpbox_fw
  ]
}

