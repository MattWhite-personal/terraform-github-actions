# Obtain Azure Front Door service tags for backend communication
data "azurerm_network_service_tags" "AzureFrontDoor-BackEnd" {
  location = var.location
  service  = "AzureFrontDoor.Backend"

}

# If using an existing Front Door, get the resource group
data "azurerm_resource_group" "afd" {
  count = var.use-existing-front-door ? 0 : 1
  name  = var.afd-resource-group
}

# Get the resource group for DNS records
data "azurerm_resource_group" "dns" {
  name  = var.dns-resource-group
}

# Ensure the DNS zone exists
data "azurerm_dns_zone" "zone" {
  name                = var.domain-name
  resource_group_name = data.azurerm_resource_group.dns.name
}

# If using an existing Front Door, get the Front Door profile
data "azurerm_cdn_frontdoor_profile" "afd" {
  count = var.use-existing-front-door ? 1 : 0
  name  = var.existing-front-door
  resource_group_name = data.azurerm_resource_group.afd[0].name
}