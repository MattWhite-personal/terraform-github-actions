terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.56.0"
    }
  }

  # Update this block with the location of your terraform state file
  backend "azurerm" {
    resource_group_name  = "terraformrg"
    storage_account_name = "terraformstoragefe832e63"
    container_name       = "terraform"
    key                  = "tf-github-actions.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}

locals {
  tags = {
    source  = "terraform"
    managed = "as-code"
  }
}

resource "azurerm_resource_group" "dnszones" {
  name     = "rg-whitefam-dnszones"
  location = "UK South"
  tags     = local.tags
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_resource_group" "cdnprofiles" {
  name     = "rg-whitefam-cdnprofiles"
  location = "UK South"
  tags     = local.tags
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_resource_group" "other-stuff" {
  name     = "RG-WhiteFam-UKS"
  location = "UK South"
  tags     = local.tags
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_cdn_profile" "cdn-mta-sts" {
  name                = "cdn-mjwmtasts"
  location            = "global"
  resource_group_name = azurerm_resource_group.cdnprofiles.name
  sku                 = "Standard_Microsoft"
  tags                = local.tags
}

resource "azurerm_cdn_frontdoor_profile" "test-mta-sts" {
  name                = "test-afd-mta-sts"
  resource_group_name = azurerm_resource_group.cdnprofiles.name
  sku_name            = "Standard_AzureFrontDoor"
}