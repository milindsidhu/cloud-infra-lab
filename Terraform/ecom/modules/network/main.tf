resource "azurerm_network_security_group" "ecom-sq-grp" {
  name                = var.vnet_sq_grp_name
  location            = var.location
  resource_group_name = var.rg_name
}

resource "azurerm_virtual_network" "ecom-vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.rg_name
  address_space       = var.address_space
  dns_servers         = var.dns_servers

  subnet {
    name           = var.vnet_subnet_name
    address_prefix = var.address_prefix_val[0]
    security_group = azurerm_network_security_group.ecom-sq-grp.id
  }
  tags = var.tags

}


#### outputs ####

output "vnet_id" {
  value = azurerm_virtual_network.ecom-vnet.id
}

output "vnet_sq_grp_id" {
  value = azurerm_network_security_group.ecom-sq-grp.id
}
