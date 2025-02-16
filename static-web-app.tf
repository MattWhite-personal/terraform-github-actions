resource "azurerm_static_web_app" "matthewjwhite-dev" {
  name                = "matthewjwhite-dev2"
  resource_group_name = azurerm_resource_group.other-stuff.name
  location            = "westeurope"
  sku_size            = "Free"
  sku_tier            = "Free"
  tags                = local.tags

  lifecycle {
    ignore_changes = [
      repository_branch,
      repository_url,
      repository_token
    ]
  }
}

resource "azurerm_static_web_app_custom_domain" "matthewjwhite-dev" {
  static_web_app_id = azurerm_static_web_app.matthewjwhite-dev.id
  domain_name       = "tfttest.matthewjwhite.co.uk"
  validation_type   = "dns-txt-token"
}
