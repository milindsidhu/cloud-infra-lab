# Variables for the main root tf file

# common vars
variable "rg_name" {}
variable "location" {}

# # az creds
# variable "az_client_id" {}
# variable "az_client_secret" {}
# variable "az_tenant_id" {}
# variable "az_subs_id" {}

# vars for vnet

variable "vnet_name" {}
variable "vnet_sq_grp_name" {}
variable "address_space" {}
variable "address_prefix_val" {
  type = list(string)
}
variable "vnet_subnet_name" {}
variable "dns_servers" {}

# vars for app service plan

variable "app_svc_plan_name" {}
variable "worker_count" {}
variable "sp_sku_name" {}
variable "sp_os_type" {}




