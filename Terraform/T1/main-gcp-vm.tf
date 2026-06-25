# provider "google" {
#   project = "terraform-101-472115"
#   region  = "us-central1"
# }

variable "deploy_compute_cluster" {
  type    = bool
  default = false
}

# module for GCP compute cluster with bastion and workload VMs
module "compute_cluster" {
  # count   = var.deploy_compute_cluster ? 1 : 0
  for_each = var.deploy_compute_cluster ? { "main" = true } : {}
  source                = "./modules/gcp/compute_cluster"
  project               = "terraform-101-472115"
  region                = "us-central1"
  zone                  = "us-central1-a"
  compute_engines_names = ["vm-01", "vm-02"]
  ssh_public_key_path   = "/Users/dex/.ssh/id_rsa.pub"
  ssh_private_key_path  = "/Users/dex/.ssh/id_rsa"
  common_labels = {
    environment = "dev"
    team        = "platform"
    owner       = "milind"
  }
}

output "bastion_ip" {
  value = try(module.compute_cluster.bastion_ip, "module not deployed")
  # value = module.compute_cluster.bastion_ip
}

output "workload_private_ips" {
  value = try(module.compute_cluster.workload_private_ips, "module not deployed")
  # value = module.compute_cluster.workload_private_ips
}

output "ansible_inventory_file" {
  value = try(module.compute_cluster.ansible_inventory_file, "module not deployed")
  # value = module.compute_cluster.ansible_inventory_file
}

### Enable for logging ###

# # module for GCP logging
# module "central_logging" {
#   source                     = "./modules/gcp/logging"
#   central_logging_project     = "terraform-101-472115"
#   central_bucket_id           = "my-central-log-bucket"
#   central_bucket_retention_days = 60
#   source_projects             = ["terraform-101-472115"]
#   sink_name                   = "export-to-central"
#   sink_filter                 = "resource.type=\"gce_instance\""
# }

# output "central_log_bucket" {
#   value = module.central_logging.central_log_bucket
# }

# output "log_sinks" {
#   value = module.central_logging.log_sinks
# }

# output "central_monitoring_project" {
#   value = module.central_logging.central_monitoring_project
# }
