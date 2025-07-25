locals {
  tls_rpt_email  = length(split("@", var.reporting-email)) == 2 ? var.reporting-email : "${var.reporting-email}@${var.domain-name}"
  policyhash     = md5("${var.mtastsmode},${join(",", var.mx-records)}")
  afd-prefix     = "cdn${var.resource-prefix}mtasts"
  storage_prefix = coalesce(var.resource-prefix, substr(replace(local.afd-prefix, "-", ""), 0, 16))
  afd-version = {
    "standard" = "Standard_AzureFrontDoor",
    "premium"  = "Premium_AzureFrontDoor",
    "default"  = "Standard_AzureFrontDoor"
  }
  front-door-id = var.use-existing-front-door ? data.azurerm_cdn_frontdoor_profile.afd[0].id : azurerm_cdn_frontdoor_profile.mta-sts[0].id
  afd-ip-ranges = flatten([
    for cidr in concat(data.azurerm_network_service_tags.AzureFrontDoor-BackEnd.ipv4_cidrs,var.runner-ip) : (
      tonumber(split("/", cidr)[1]) >= 31 ?
      [
        for i in range(
          tonumber(split("/", cidr)[1]) == 32 ? 1 : 2
        ) : cidrhost(cidr, i)
      ] :
      [cidr]
    )
  ])
  storage-account-name = "st${local.storage_prefix}mtasts"
}

#resource "azurerm_cdn_profile" "cdnmtasts" {
#  count               = var.use-existing-cdn-profile ? 0 : 1
#  name                = "cdn-${local.cdn-prefix}"
#  location            = "global"
#  resource_group_name = var.cdn-resource-group
#  sku                 = "Standard_Microsoft"
#  tags                = var.tags
#}

#resource "azurerm_cdn_endpoint" "mtastsendpoint" {
#  name                = local.cdn-prefix
#  profile_name        = var.use-existing-cdn-profile ? var.existing-cdn-profile : azurerm_cdn_profile.cdnmtasts[0].name
#  location            = "global"
#  resource_group_name = var.cdn-resource-group
#  tags                = var.tags
#  is_http_allowed     = false

#  origin {
#    name      = "mtasts-endpoint"
#    host_name = azurerm_storage_account.stmtasts.primary_web_host
#  }

#  origin_host_header = azurerm_storage_account.stmtasts.primary_web_host

#  delivery_rule {
#    name  = "EnforceHTTPS"
#    order = "1"

#    request_scheme_condition {
#      operator     = "Equal"
#      match_values = ["HTTP"]
#    }

#    url_redirect_action {
#      redirect_type = "Found"
#      protocol      = "Https"
#    }
#  }
#}

#resource "azurerm_cdn_endpoint_custom_domain" "mtastscustomdomain" {
#  name            = local.cdn-prefix
#  cdn_endpoint_id = azurerm_cdn_endpoint.mtastsendpoint.id
#  host_name       = "${azurerm_dns_cname_record.mta-sts.name}.${azurerm_dns_cname_record.mta-sts.zone_name}"

#  cdn_managed_https {
#    certificate_type = "Dedicated"
#    protocol_type    = "ServerNameIndication"
#    tls_version      = "TLS12"
#  }
#  depends_on = [azurerm_dns_cname_record.mta-sts, azurerm_dns_cname_record.cdnverify]
#}

