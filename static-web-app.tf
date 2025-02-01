resource "azurerm_static_web_app" "matthewjwhite-dev" {
  name                = "matthewjwhite-dev"
  resource_group_name = azurerm_resource_group.webservers.name
  location            = "westeurope"
  sku_size            = "Standard"
  sku_tier            = "Standard"
  repository_url      = "https://github.com/MattWhite-personal/matthewjwhite.co.uk"
  repository_branch   = "main"
  repository_token    = var.azure_swa_pat
  tags = local.tags
}

#resource "azurerm_static_web_app_custom_domain" "matthewjwhite-dev" {
#  static_web_app_id = azurerm_static_web_app.matthewjwhite-dev.id
#  domain_name       = "dev.matthewjwhite.co.uk"
#  validation_type   = "cname-delegation"
#}
