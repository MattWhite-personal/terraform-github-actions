resource "azurerm_dns_zone" "tftest2-mjw" {
  name                = "tfttest2.matthewjwhite.co.uk"
  resource_group_name = azurerm_resource_group.dnszones.name
  lifecycle {
    prevent_destroy = true
  }
  tags = local.tags
}

module "tftest2-records" {
  source       = "./module/dnsrecords"
  zone_name    = azurerm_dns_zone.tftest2-mjw.name
  rg_name      = azurerm_resource_group.dnszones.name
  tags         = local.tags
  a-records    = []
  aaaa-records = []
  caa-records = [
    {
      name = "@"
      ttl  = 3600
      records = [
        {
          flags = 0
          tag   = "issue"
          value = "digicert.com"
        },
        {
          flags = 0
          tag   = "issue"
          value = "letsencrypt.org"
        },
        {
          flags = 0
          tag   = "iodef"
          value = "mailto:dnscaa@matthewjwhite.co.uk"
        }
      ]
    }
  ]
  cname-records = []
  mx-records = [
    {
      name = "@"
      ttl  = 3600
      records = [
        {
          preference = 0
          exchange   = "tftest2-mjw.mail.protection.outlook.com"
        }
      ]
    }
  ]
  ptr-records = []
  srv-records = []
  txt-records = [
    {
      name = "@",
      records = [
        "MS=ms59722365",
        "v=spf1 include:spf.protection.outlook.com -all",
      ]
    }

  ]
}

module "tftest2-mjw-mtasts" {
  source                  = "./module/mtasts"
  use-existing-front-door = true
  existing-front-door     = azurerm_cdn_frontdoor_profile.test-mta-sts.name
  afd-resource-group      = azurerm_resource_group.cdnprofiles.name
  afd-version             = "standard"
  dns-resource-group      = azurerm_resource_group.dnszones.name
  mx-records              = ["tftest2-mjw.mail.protection.outlook.com"]
  domain-name             = azurerm_dns_zone.tftest-mjw.name
  depends_on              = [azurerm_resource_group.cdnprofiles, azurerm_resource_group.dnszones]
  reporting-email         = "tls-reports@matthewjwhite.co.uk"
  stg-resource-group      = "RG-WhiteFam-UKS"
  resource-prefix         = "mwtftest2"
  tags                    = local.tags
  permitted-ips           = local.permitted_ips
  runner-ip               = var.runner-ip
}
