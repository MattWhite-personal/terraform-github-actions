resource "azurerm_static_web_app" "matthewjwhite-dev" {
  name                = "matthewjwhite-dev"
  resource_group_name = azurerm_resource_group.other-stuff.name
  location            = "westeurope"
  sku_size            = "Standard"
  sku_tier            = "Standard"
  tags                = local.tags
}

#resource "azurerm_static_web_app_custom_domain" "matthewjwhite-dev" {
#  static_web_app_id = azurerm_static_web_app.matthewjwhite-dev.id
#  domain_name       = "dev.matthewjwhite.co.uk"
#  validation_type   = "cname-delegation"
#}
