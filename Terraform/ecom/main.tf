# Read the tags from a local file
locals {
  tags = jsondecode(file("tags.json"))
}

# set the provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }

  # backend "local" {
  #   path = "$TF_VAR_HOME/WORKSPACE/StateFileStorage/terraform.tfstate"
  # }

  # backend "local" {
  #   path = "$TF_VAR_HOME/WORKSPACE/StateFileStorage/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}

  # # Required info for login to Azure
  # client_id       = var.az_client_id != "" ? var.az_client_id : ""
  # client_secret   = var.az_client_secret != "" ? var.az_client_secret : ""
  # tenant_id       = var.az_tenant_id != "" ? var.az_tenant_id : ""
  # subscription_id  = var.az_subs_id != "" ? var.az_subs_id : ""
}


# create a resource group
resource "azurerm_resource_group" "ecom_rg" {
  name     = var.rg_name
  location = var.location
  tags     = local.tags

}

# create an app service plan
module "my_az_servicePlan" {
  source            = "./modules/servicePlan"
  app_svc_plan_name = var.app_svc_plan_name
  location          = var.location
  rg_name           = var.rg_name
  sp_os_type        = var.sp_os_type
  worker_count      = var.worker_count
  sp_sku_name       = var.sp_sku_name

  tags = local.tags

  depends_on = [azurerm_resource_group.ecom_rg]

}

# create a vnet security group and a vnet
module "my_az_vnet" {
  source             = "./modules/network"
  vnet_name          = var.vnet_name
  vnet_sq_grp_name   = var.vnet_sq_grp_name
  address_space      = var.address_space
  location           = var.location
  rg_name            = var.rg_name
  dns_servers        = var.dns_servers
  vnet_subnet_name   = var.vnet_subnet_name
  address_prefix_val = var.address_prefix_val

  tags = local.tags

  depends_on = [azurerm_resource_group.ecom_rg]

}