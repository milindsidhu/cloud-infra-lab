# common vars
variable "rg_name" {}
variable "location" {}
variable "tags" {
  type = map(string)
}

# Variables for the VNet

variable "vnet_name" {}
variable "address_space" {}
variable "address_prefix_val" {}
variable "dns_servers" {}
variable "vnet_subnet_name" {}

# vars for vnet security group

variable "vnet_sq_grp_name" {}
