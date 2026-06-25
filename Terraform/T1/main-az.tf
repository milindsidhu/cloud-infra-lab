# # --------------------------
# # Resource Group
# # --------------------------
# resource "azurerm_resource_group" "rg1" {
#   name     = "rg-aks-01"
#   location = "East US"
# }

# # --------------------------
# # Virtual Network
# # --------------------------
# resource "azurerm_virtual_network" "vnet" {
#   name                = "vnet-aks-01"
#   location            = azurerm_resource_group.rg1.location
#   resource_group_name = azurerm_resource_group.rg1.name
#   address_space       = ["10.0.0.0/16"]

#   depends_on = [azurerm_resource_group.rg1]
# }

# # --------------------------
# # Subnet for AKS
# # --------------------------
# resource "azurerm_subnet" "subnet" {
#   name                 = "subnet-aks"
#   resource_group_name  = azurerm_resource_group.rg1.name
#   virtual_network_name = azurerm_virtual_network.vnet.name
#   address_prefixes     = ["10.0.1.0/24"]

#   service_endpoints = ["Microsoft.Storage", "Microsoft.Sql"]

#   depends_on = [azurerm_virtual_network.vnet]
# }

# # --------------------------
# # AKS Cluster (Private)
# # --------------------------
# resource "azurerm_kubernetes_cluster" "aks" {
#   name                = "aks-cluster-01"
#   location            = azurerm_resource_group.rg1.location
#   resource_group_name = azurerm_resource_group.rg1.name
#   dns_prefix          = "aksprefix"
#   sku_tier            = "Free"
#   kubernetes_version  = "1.32.6"

#   default_node_pool {
#     name           = "default"
#     node_count     = 2
#     vm_size        = "Standard_B2s"
#     vnet_subnet_id = azurerm_subnet.subnet.id
#   }

#   identity {
#     type = "SystemAssigned"
#   }

#   network_profile {
#     network_plugin    = "azure"
#     network_policy    = "calico"
#     load_balancer_sku = "standard"

#     service_cidr       = "10.1.0.0/16"   # must not overlap with subnet
#     dns_service_ip     = "10.1.0.10"     # inside service_cidr
#     # docker_bridge_cidr = "172.17.0.1/16"
#     # outbound_type      = "userDefinedRouting"          # nodes will not have outbound internet
#   }

#   private_cluster_enabled = true

#   # azure_active_directory_role_based_access_control {
#   # # replace with your AAD group object ID
#   # }

#   tags = {
#     Environment = "Development"
#     Project     = "Private AKS Cluster"
#   }

#   depends_on = [azurerm_subnet.subnet]
# }
