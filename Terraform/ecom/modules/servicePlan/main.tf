resource "azurerm_service_plan" "app_svc_plan" {
  name                = var.app_svc_plan_name
  location            = var.location
  resource_group_name = var.rg_name
  os_type             = var.sp_os_type
  sku_name            = var.sp_sku_name
  worker_count        = var.worker_count

  tags = var.tags

}
