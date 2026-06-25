variable "deploy_gke" {
  type    = bool
  default = true
}

module "gke_private" {
  # count   = var.deploy_gke ? 1 : 0
  for_each = var.deploy_gke ? { "main" = true } : {}
  source = "./modules/gcp/gke"

  project_id   = "terraform-101-472115"
  region       = "us-central1"
  network_name = "dev-gke-vpc"
  subnet_cidr  = "10.20.0.0/20"
  cluster_name = "dev-gke"
  node_count   = 3
  machine_type = "e2-medium"
  ssh_public_key_path = "/Users/dex/.ssh/id_rsa.pub"
#   enable_private_nodes = true
#   enable_private_endpoint = false
  node_service_account = "terraform-sa@terraform-101-472115.iam.gserviceaccount.com"
#   authorized_networks = [
#     { cidr = "203.0.113.0/32" , description = "my-office-ip" }
#   ]
#   master_ipv4_cidr_block = "172.16.0.0/28"

  enable_private_nodes    = true
  enable_private_endpoint = true   # private-only control plane
  authorized_networks     = []     # auto-ignored
  master_ipv4_cidr_block  = "172.16.0.0/28"
}

