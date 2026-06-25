# Define the variables

# common vars
location = "West Europe"
rg_name  = "ecommerce-rg"


# vars for vnet
vnet_name          = "ecom-vnet"
vnet_sq_grp_name   = "ecommerce-security-grp"
address_space      = ["10.0.0.0/16"]
address_prefix_val = ["10.0.1.0/24"]
vnet_subnet_name   = "subnet_01"

# vars for app service 
app_svc_plan_name = "ecom-svc-plan"
sp_os_type        = "Linux"
sp_sku_name       = "B1"
worker_count      = "2"
dns_servers       = ["10.0.0.4", "10.0.0.5"]