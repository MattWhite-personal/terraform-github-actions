resource "azurerm_static_web_app" "matthewjwhite-dev" {
  name                = "matthewjwhite-dev2"
  resource_group_name = azurerm_resource_group.other-stuff.name
  location            = "westeurope"
  sku_size            = "Standard"
  sku_tier            = "Standard"
  tags                = local.tags
  repository_url      = "https://github.com/MattWhite-personal/matthewjwhite.co.uk"
  repository_branch   = "main"
  repository_token    = var.azure_swa_pat
}

#resource "azurerm_static_web_app_custom_domain" "matthewjwhite-dev" {
#  static_web_app_id = azurerm_static_web_app.matthewjwhite-dev.id
#  domain_name       = "dev.matthewjwhite.co.uk"
#  validation_type   = "cname-delegation"
#}
