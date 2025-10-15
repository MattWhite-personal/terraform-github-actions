resource "azurerm_static_web_app" "matthewjwhite-dev" {
  name                = "matthewjwhite-dev2"
  resource_group_name = azurerm_resource_group.other-stuff.name
  location            = "westeurope"
  sku_size            = "Standard"
  sku_tier            = "Standard"
  tags                = local.tags

  lifecycle {
    ignore_changes = [
      repository_branch,
      repository_url,
      repository_token
    ]
  }
}

#resource "azurerm_static_web_app_custom_domain" "matthewjwhite-dev" {
#  static_web_app_id = azurerm_static_web_app.matthewjwhite-dev.id
#  domain_name       = "tfttest.matthewjwhite.co.uk"
#  validation_type   = "dns-txt-token"
#}

resource "azurerm_cdn_frontdoor_endpoint" "static-web-app" {
  name                     = "afd-ep-swa-test"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.test-mta-sts.id
}

resource "azurerm_cdn_frontdoor_origin_group" "static-web-app" {
  name                     = "afd-og-swa-test"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.test-mta-sts.id

  load_balancing {}
}

resource "azurerm_cdn_frontdoor_origin" "static-web-app" {
  name                           = "afd-o-swa-test"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.static-web-app.id
  enabled                        = true
  certificate_name_check_enabled = false
  host_name                      = azurerm_static_web_app.matthewjwhite-dev.default_host_name
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_static_web_app.matthewjwhite-dev.default_host_name
  priority                       = 1
  weight                         = 1
}

resource "azurerm_cdn_frontdoor_route" "static-web-app" {
  name                          = "afd-rt-swa-test"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.static-web-app.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.static-web-app.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.static-web-app.id]

  supported_protocols             = ["Http", "Https"]
  patterns_to_match               = ["/*"]
  forwarding_protocol             = "HttpsOnly"
  link_to_default_domain          = false
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.static-web-app.id]
  https_redirect_enabled          = true
}

resource "azurerm_dns_a_record" "static-web-app" {
  name                = "@"
  zone_name           = azurerm_dns_zone.tftest-mjw.name
  resource_group_name = azurerm_resource_group.dnszones.name
  ttl                 = 300
  target_resource_id  = azurerm_cdn_frontdoor_endpoint.static-web-app.id
}

resource "azurerm_dns_txt_record" "dnsauth" {
  name                = "_dnsauth"
  zone_name           = azurerm_dns_zone.tftest-mjw.name
  resource_group_name = azurerm_resource_group.dnszones.name
  ttl                 = 300

  record {
    value = azurerm_cdn_frontdoor_custom_domain.static-web-app.validation_token
  }
}

resource "azurerm_cdn_frontdoor_custom_domain" "static-web-app" {
  name                     = "afd-cd-swa-test"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.test-mta-sts.id
  #dns_zone_id              = azurerm_dns_zone.tftest-mjw.id
  host_name = "${azurerm_dns_cname_record.static-web-app.name}.${azurerm_dns_cname_record.static-web-app.zone_name}"

  tls {
    certificate_type    = "ManagedCertificate"
  }

}

resource "azurerm_cdn_frontdoor_custom_domain_association" "static-web-app" {
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.static-web-app.id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.static-web-app.id]
}
