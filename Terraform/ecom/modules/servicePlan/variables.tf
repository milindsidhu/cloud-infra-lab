# common vars
variable "rg_name" {}
variable "location" {}
variable "tags" {
  type = map(string)
}

# vars for app service plan
variable "app_svc_plan_name" {}
variable "sp_os_type" {}
variable "sp_sku_name" {}
variable "worker_count" {}
