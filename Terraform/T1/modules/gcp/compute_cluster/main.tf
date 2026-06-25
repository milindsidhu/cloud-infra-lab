# VPC
resource "google_compute_network" "vpc_network" {
  name                    = "compute-engine-vpc"
  auto_create_subnetworks = false
  description             = "VPC for Compute Cluster"
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "compute-engine-subnet"
  ip_cidr_range = var.vpc_ip_cidr_range
  region        = var.region
  network       = google_compute_network.vpc_network.id

  depends_on = [google_compute_network.vpc_network]
}

# Firewall
resource "google_compute_firewall" "firewall" {
  name    = "allow-ssh-http-https"
  network = google_compute_network.vpc_network.id

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh-http-https"]

  depends_on = [google_compute_network.vpc_network]
}

# Bastion host
resource "google_compute_instance" "bastion" {
  name         = "bastion-host"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image  = "debian-cloud/debian-11"
      labels = merge(var.common_labels, { server = "bastion" })
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {}
  }

  metadata = {
    ssh-keys = "milindsidhu:${file(var.ssh_public_key_path)}"
  }

  labels = merge(var.common_labels, { server = "bastion" })
  tags   = ["allow-ssh-http-https"]

  depends_on = [
    google_compute_network.vpc_network,
    google_compute_subnetwork.subnet,
    google_compute_firewall.firewall
  ]
}

# Workload VMs
resource "google_compute_instance" "vm_instance" {
  for_each     = toset(var.compute_engines_names)
  name         = each.value
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image  = "debian-cloud/debian-11"
      labels = var.common_labels
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet.id
  }

  metadata = {
    ssh-keys = "milindsidhu:${file(var.ssh_public_key_path)}"
    startup-script = <<-EOT
      #!/bin/bash
      curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
      bash add-google-cloud-ops-agent-repo.sh --also-install
    EOT
  }

  labels = var.common_labels
  tags   = ["allow-ssh-http-https"]

  depends_on = [
    google_compute_network.vpc_network,
    google_compute_subnetwork.subnet,
    google_compute_firewall.firewall
  ]
}

# Cloud Router and NAT
resource "google_compute_router" "router" {
  name    = "compute-nat-router"
  network = google_compute_network.vpc_network.name
  region  = var.region

  depends_on = [
    google_compute_network.vpc_network,
    google_compute_subnetwork.subnet
  ]
}

resource "google_compute_router_nat" "nat" {
  name                               = "compute-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  depends_on = [google_compute_router.router]
}

# Ansible inventory
resource "local_file" "ansible_inventory" {
  filename = "${path.root}/ansible/ansible_inventory.ini"

  content = <<-EOT
[bastion]
bastion-host ansible_host=${google_compute_instance.bastion.network_interface[0].access_config[0].nat_ip} ansible_user=milindsidhu ansible_ssh_private_key_file=${var.ssh_private_key_path}

[workload_vms]
%{ for name, vm in google_compute_instance.vm_instance ~}
${name} ansible_host=${vm.network_interface[0].network_ip} ansible_user=milindsidhu ansible_ssh_private_key_file=${var.ssh_private_key_path} ansible_ssh_common_args='-o ProxyJump=milindsidhu@${google_compute_instance.bastion.network_interface[0].access_config[0].nat_ip} -o StrictHostKeyChecking=no'
%{ endfor ~}
  EOT

  depends_on = [
    google_compute_instance.bastion,
    google_compute_instance.vm_instance
  ]
}

# NGINX upstream vars
resource "local_file" "nginx_upstream" {
  filename = "${path.root}/ansible/nginx_upstream.yml"

  content = <<-EOT
app_backends:
%{ for name, vm in google_compute_instance.vm_instance ~}
- ${vm.network_interface[0].network_ip}:8080
%{ endfor ~}
  EOT

  depends_on = [google_compute_instance.vm_instance]
}

# Run Ansible
resource "null_resource" "ansible_provision" {
  depends_on = [
    local_file.ansible_inventory,
    local_file.nginx_upstream,
    google_compute_router_nat.nat
  ]

  # triggers = {
  #   always_run = timestamp()
  # }

  provisioner "local-exec" {
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }

    command = <<-EOT
      ansible-playbook -i "${local_file.ansible_inventory.filename}" ${path.root}/ansible/playbook.yml --limit workload_vms
      ansible-playbook -i "${local_file.ansible_inventory.filename}" ${path.root}/ansible/nginx_reverse_proxy.yml --limit bastion-host
    EOT
  }
}
