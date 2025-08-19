---
title: "Managing DNS records as code"
pubDate: "2025-04-21"
categories:
  - "infrastructure"
tags:
  - "terraform"
  - "infrastructure as code"
  - "DNS"
  - "automation"
heroImage: "/blog-terraform-dns.png"
description: "How to manage DNS zones and records in Microsoft Azure DNS with Terraform used to manage the infrastructure as code and optional delivery of MTA-STS hosting for mail security."
---

Over my years working with technology I have had to manage public DNS records for numerous clients as well as my own internal domains and projects. Traditionally this was all managed manually with changes made within a registrar's portal and the records updated manually when a change was required. Whilst this technically works it does lead to the risk of human error with typos introduced into records potentially disrupting access to services.

In the management of personal IT services I have regularly worked in a similar way to manually set and update the A, CNAME, TXT, NS, MX etc records that are required for my family's domains as well as those for my personal projects.

More and more of my projects are running in Microsoft Azure and as I mentioned in a previous post I wanted to work more with Infrastructure as Code and spend less time click-opsing my way through life. I therefore decided to look at how to manage my DNS zones as code. My goal was to

- have a copy of the key records that make my digital life work in case they need to be recreated
- create a repeatable structure that would enable multiple zones to managed in a common way
- reduce the repetitive nature of repeating code where it is not required
- be able to reference multiple other resources that are also managed as code within my own code
- support the wider management of email security such as MTA-STS and TLS-RPT records and their supporting resources
- make sure that the code could be used by others if they found it useful (partly why I am writing this blog post)

# DNS as code

As with all projects I started out creating a new Github repository that would store my code. Initially this was a private repository to keep the management of the DNS zones secretive however I quickly changed this to public because it enabled me to better check for bad code using the security features built into Github and DNS is a public service so the data that is published can be discovered in other ways.

I structured the repository with the required `main.tf`, added some additional terraform files to support splitting out references to remote state `remote-state.tf` (I use this to read data from other projects and to keep this repository focussed purely on DNS related things) and also any outputs `outputs.tf` that the code may need to handle in other places. Each DNS zone that I manage would have its own `.tf` file and to keep them together the files are all prefixed with `zone_`. Finally I have a folder called `modules` that contains the code that will support the deployment of MTA-STS records and the code for each Azure DNS zone and their record sets.

## Terraform Modules

To reduce the duplication of code for multiple records of the same type a custom module is defined that enables the DNS zone to be managed in a common way and also allows for different variations within the particular record type (e.g. A records could refer to an IP address or to be an alias of a separate resource in Azure).

The `dnsrecords` module exists within the wider repository and provides support for the following record types

| record Type   | Detail                                                                                                      | Required |
| ------------- | ----------------------------------------------------------------------------------------------------------- | -------- |
| A records     | Address records that return IPv4 address(es)                                                                | TRUE     |
| AAAA records  | Address records that return IPv6 address(es)                                                                | TRUE     |
| CAA records   | Certification Authority Authorization records that define approved CAs for a host or domain                 | TRUE     |
| CNAME records | Canonical Name records that act as an alias for another DNS record                                          | TRUE     |
| MX records    | Mail Exchange records to support the delivery of email for a domain                                         | TRUE     |
| NS records    | Name Server records to define authoritative DNS servers for a particular zone                               | FALSE    |
| PTR records   | Pointer records to support the reverse lookup of DNS names to other records                                 | FALSE    |
| SRV records   | Service Locator records are generalised locator records for wider services                                  | TRUE     |
| TXT records   | Text records that support arbitrary text records and more modern services such as mail security SPF records | TRUE     |

Other Azure DNS record types are possible but these are the most common record types in use and covered all the use cases I had. The module could be expanded to support wider record types.

The Module is made up of three files which are set out below:

- `main.tf` - The bulk of the terraform module
- `outputs.tf` - Any data that is returned by the module to wider code (currently not used)
- `variables.tf` - All variables that are passed into the module to be successful

The module assumes that you have a DNS Zone already existing in Azure and in a resource group that Terraform can manipulate and manage (I cover the creation and life cycle of the DNS zones outside of this module but in the wider repository). They zone name and resource group name are passed in as variables along with lists of custom objects for each record type. By default all records have a Time To Live (TTL) value of 1 hour which can be overridden by the list value.

### main.tf

This file handles the majority of the resource deployment and management.

There is a lot of use of the [for_each](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each) meta-argument in Terraform to produce multiple copies of the same record type based on the list of inputs passed as variables into the module. The module also leverages the [coalesce](https://developer.hashicorp.com/terraform/language/functions/coalesce) function to enable the module to either use a default value from the underlying module or pass in the one defined as code. Both of these can be seen in the A-records section. Finally I also leverage [Conditional Expressions](https://developer.hashicorp.com/terraform/language/expressions/conditionals) to define the resource depending on another value

```terraform
resource "azurerm_dns_a_record" "a" {
  for_each = {
    for record in var.a-records : record.name => record
  }
  name                = each.value["name"]
  zone_name           = var.zone_name
  resource_group_name = var.rg_name
  ttl                 = coalesce(each.value["ttl"], var.ttl)
  records             = each.value["isAlias"] ? null : each.value["records"]
  target_resource_id  = each.value["isAlias"] ? each.value["resourceID"] : null
  tags                = var.tags
}
```

- At the top we iterate through all the objects of `var.a-records` to produce multiple `azurerm_dns_a_record` resources
- the coalesce function is used to prefer a TTL value for the record from the input variable or if not defined use the default time to live defined in `var.ttl`
- the `isAlias` boolean is evaluated in `records` and `target_resource_id` and depending on whether this is true or false sets the correct attribute and leaves the other as null.

The result of all of this is that I have defined my record type once, can deploy multiple of the same resource type and respond to different requirements for those resources in a single code definition.

A copy is listed below but the live file can be viewed here [main.tf](https://github.com/MattWhite-personal/dns-iac/blob/main/terraform/module/dnsrecords/main.tf)

```terraform
resource "azurerm_dns_a_record" "a" {
  for_each = {
    for record in var.a-records : record.name => record
  }
  name                = each.value["name"]
  zone_name           = var.zone_name
  resource_group_name = var.rg_name
  ttl                 = coalesce(each.value["ttl"], var.ttl)
  records             = each.value["isAlias"] ? null : each.value["records"]
  target_resource_id  = each.value["isAlias"] ? each.value["resourceID"] : null
  tags                = var.tags
}

resource "azurerm_dns_aaaa_record" "aaaa" {
  for_each = {
    for record in var.aaaa-records : record.name => record
  }
  name                = each.value["name"]
  zone_name           = var.zone_name
  resource_group_name = var.rg_name
  ttl                 = coalesce(each.value["ttl"], var.ttl)
  records             = each.value["isAlias"] ? null : each.value["records"]
  target_resource_id  = each.value["isAlias"] ? each.value["resourceID"] : null
  tags                = var.tags
}

resource "azurerm_dns_caa_record" "caa" {
  for_each = {
    for record in var.caa-records : record.name => record
  }
  name                = each.value["name"]
  zone_name           = var.zone_name
  resource_group_name = var.rg_name
  ttl                 = coalesce(each.value["ttl"], var.ttl)
  tags                = var.tags

  dynamic "record" {
    for_each = each.value["records"]
    content {
      flags = record.value["flags"]
      tag   = record.value["tag"]
      value = record.value["value"]
    }
  }
}

resource "azurerm_dns_cname_record" "cname" {
  for_each = {
    for record in var.cname-records : record.name => record
  }
  name                = each.value["name"]
  zone_name           = var.zone_name
  resource_group_name = var.rg_name
  ttl                 = coalesce(each.value["ttl"], var.ttl)
  record              = each.value["isAlias"] ? null : each.value["record"]
  target_resource_id  = each.value["isAlias"] ? each.value["resourceID"] : null
  tags                = var.tags
}

resource "azurerm_dns_mx_record" "mx" {
  for_each = {
    for record in var.mx-records : record.name => record
  }
  name                = each.value["name"]
  zone_name           = var.zone_name
  resource_group_name = var.rg_name
  ttl                 = coalesce(each.value["ttl"], var.ttl)
  tags                = var.tags

  dynamic "record" {
    for_each = lookup(each.value, "records", null)
    content {
      preference = record.value["preference"]
      exchange   = record.value["exchange"]
    }
  }
}

resource "azurerm_dns_ns_record" "ns" {
  for_each = {
    for record in var.ns-records : record.name => record
  }
  name                = each.value["name"]
  zone_name           = var.zone_name
  resource_group_name = var.rg_name
  ttl                 = coalesce(each.value["ttl"], var.ttl)
  tags                = var.tags

  records = each.value["records"]
}

resource "azurerm_dns_ptr_record" "ptr" {
  for_each = {
    for record in var.ptr-records : record.name => record
  }
  name                = each.value["name"]
  zone_name           = var.zone_name
  resource_group_name = var.rg_name
  ttl                 = coalesce(each.value["ttl"], var.ttl)
  records             = each.value["records"]
  tags                = var.tags
}

resource "azurerm_dns_srv_record" "srv" {
  for_each = {
    for record in var.srv-records : record.name => record
  }
  name                = each.value["name"]
  zone_name           = var.zone_name
  resource_group_name = var.rg_name
  ttl                 = coalesce(each.value["ttl"], var.ttl)
  tags                = var.tags

  dynamic "record" {
    for_each = each.value["records"]
    content {
      priority = record.value["priority"]
      weight   = record.value["weight"]
      port     = record.value["port"]
      target   = record.value["target"]
    }
  }
}

resource "azurerm_dns_txt_record" "txt" {
  for_each = {
    for record in var.txt-records : record.name => record
  }
  name                = each.value["name"]
  zone_name           = var.zone_name
  resource_group_name = var.rg_name
  ttl                 = coalesce(each.value["ttl"], var.ttl)
  tags                = var.tags

  dynamic "record" {
    for_each = each.value["records"]
    content {
      value = record.value
    }
  }
}
```

### variables.tf

This file defines the format of the variables used to manage DNS records. A copy is listed below but the live file can be viewed here [variables.tf](https://github.com/MattWhite-personal/dns-iac/blob/main/terraform/module/dnsrecords/variables.tf)

```terraform
variable "zone_name" {
  description = "Name of the zone add to records to"
  type        = string
}

variable "rg_name" {
  description = "Name of the resource group to add the records"
  type        = string
}

variable "a-records" {
  description = "A records to attach to the domain"
  type = list(object({
    name       = string
    ttl        = optional(number)
    isAlias    = bool
    records    = optional(list(string))
    resourceID = optional(string)
  }))
  default = []
}

variable "aaaa-records" {
  description = "AAAA records to attach to the domain"
  type = list(object({
    name       = string
    ttl        = optional(number)
    isAlias    = bool
    records    = optional(list(string))
    resourceID = optional(string)
  }))
  default = []
}

variable "caa-records" {
  description = "CAA records for the domain"
  type = list(object({
    name = string
    ttl  = optional(number)
    records = list(object({
      flags = number
      tag   = string
      value = string
    }))
  }))
}

variable "cname-records" {
  description = "CNAME records for the domain"
  type = list(object({
    name       = string
    isAlias    = bool
    record     = optional(string)
    resourceID = optional(string)
    ttl        = optional(number)
  }))
  default = []
}

variable "mx-records" {
  description = "MX Records for the domain"
  type = list(object({
    name = string
    ttl  = optional(number)
    records = list(object({
      preference = number
      exchange   = string
    }))
  }))
}

variable "ns-records" {
  description = "NS records to attach to the domain"
  type = list(object({
    name    = string
    ttl     = optional(number)
    records = list(string)
  }))
  default = []
}

variable "ptr-records" {
  description = "PTR records to attach to the domain"
  type = list(object({
    name    = string
    ttl     = optional(number)
    records = list(string)
  }))
  default = []
}

variable "srv-records" {
  description = "SRV records for the domain"
  type = list(object({
    name = string
    ttl  = optional(number)
    records = list(object({
      priority = number
      weight   = number
      port     = number
      target   = string
    }))
  }))
}

variable "txt-records" {
  description = "Text records"
  type = list(object({
    name    = string
    ttl     = optional(number)
    records = set(string)
  }))
  default = []
}

variable "ttl" {
  type    = number
  default = 3600
}

variable "tags" {
  description = "Azure Resource tags to be added to all resources"
}
```

## Zone files

Now the module is defined to create multiple types of different records for a particular DNS zone it is necessary to define the DNS zones and records outside of the module. This is done in each of the `zone_<domain-name>.tf` files in the parent folder of the repository. The zone file contains three sets of resources

1. A resource for the DNS zone that is being managed
   ```terraform
   resource "azurerm_dns_zone" "domain-name-com" {
     name                = "domain-name.com"
     resource_group_name = azurerm_resource_group.dnszones.name
     tags                = local.tags
     lifecycle {
         prevent_destroy = true
     }
   }
   ```
2. A module block that contains each record type that is managed

   ```terraform
   module "zone-records" {
     source    = "./module/dnsrecords"
     zone_name = azurerm_dns_zone.domain-name-com.name
     rg_name   = azurerm_resource_group.dnszones.name
     tags      = local.tags

     a-records     = []
     aaaa-records  = []
     caa-records   = []
     cname-records = []
     mx-records    = []
     ns-records    = []
     ptr-records   = []
     txt-records   = []
   }
   ```

3. A module block that defines the wider Azure core to manage MTA-STS records (this is outside the scope of this post but shown below for reference)
   ```terraform
   module "zone-mtasts" {
     source                   = "./module/mtasts"
     use-existing-cdn-profile = true
     existing-cdn-profile     = azurerm_cdn_profile.cdn-mta-sts.name
     cdn-resource-group       = azurerm_resource_group.cdnprofiles.name
     dns-resource-group       = azurerm_resource_group.dnszones.name
     stg-resource-group       = "rg-mta-sts"
     mx-records               = ["mx1.domain.com", "mx2.domain.com"]
     domain-name              = azurerm_dns_zone.domain-name-com.name
     depends_on               = [azurerm_resource_group.cdnprofiles, azurerm_resource_group.dnszones]
     reporting-email          = "tls-reports@domain-name.com"
     resource-prefix          = "mtasts"
     tags                     = local.tags
     permitted-ips            = local.permitted_ips
   }
   ```

### Example zone file

The following code sample shows a reference DNS zone file that I look after for my personal domain. The block below was accurate at the time of publication but the live version is available here [zone_matthewjwhite.co.uk.tf](https://github.com/MattWhite-personal/dns-iac/blob/main/terraform/zone_matthewjwhite.co.uk.tf)

```terraform
resource "azurerm_dns_zone" "matthewjwhite-co-uk" {
  name                = "matthewjwhite.co.uk"
  resource_group_name = azurerm_resource_group.dnszones.name
  tags                = local.tags
  lifecycle {
    prevent_destroy = true
  }
}

module "mjw-records" {
  source    = "./module/dnsrecords"
  zone_name = azurerm_dns_zone.matthewjwhite-co-uk.name
  rg_name   = azurerm_resource_group.dnszones.name
  tags      = local.tags

  a-records = [
    {
      name       = "@"
      isAlias    = true
      resourceID = data.terraform_remote_state.web-server.outputs.mjw-swa-id
      ttl        = 60
    },
    {
      name    = "ha",
      records = ["90.196.227.99"],
      isAlias = false
    },
    {
      name    = "localhost",
      records = ["127.0.0.1"],
      isAlias = false
    },
    {
      name    = "mail",
      records = ["81.174.249.251"],
      isAlias = false
    },
    {
      name    = "vpn",
      records = ["5.64.45.6"],
      ttl     = 300
      isAlias = false
    }
  ]
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
  cname-records = [
    {
      name    = "autodiscover",
      record  = "autodiscover.outlook.com.",
      isAlias = false
    },
    {
      name    = "d7f095024217c24089a3adf793728469",
      record  = "verify.bing.com.",
      ttl     = 600
      isAlias = false
    },
    {
      name    = "enterpriseenrollment",
      record  = "enterpriseenrollment.manage.microsoft.com.",
      isAlias = false
    },
    {
      name    = "enterpriseregistration",
      record  = "enterpriseregistration.windows.net.",
      isAlias = false
    },
    {
      name    = "leatherhead",
      record  = "mail.matthewjwhite.co.uk.",
      isAlias = false
    },
    {
      name    = "lyncdiscover",
      record  = "webdir.online.lync.com.",
      isAlias = false
    },
    {
      name    = "mailgate",
      record  = "mail.matthewjwhite.co.uk.",
      isAlias = false
    },
    {
      name    = "msoid",
      record  = "clientconfig.microsoftonline-p.net.",
      isAlias = false
    },
    {
      name    = "newsite",
      record  = "mjwsite.azurewebsites.net",
      isAlias = false
    },
    {
      name    = "selector1-azurecomm-prod-net._domainkey",
      record  = "selector1-azurecomm-prod-net._domainkey.azurecomm.net",
      isAlias = false
    },
    {
      name    = "selector1._domainkey",
      record  = "selector1-matthewjwhite-co-uk._domainkey.thewhitefamily.onmicrosoft.com.",
      isAlias = false
    },
    {
      name    = "selector2-azurecomm-prod-net._domainkey",
      record  = "selector2-azurecomm-prod-net._domainkey.azurecomm.net",
      isAlias = false
    },
    {
      name    = "selector2._domainkey",
      record  = "selector2-matthewjwhite-co-uk._domainkey.thewhitefamily.onmicrosoft.com.",
      isAlias = false
    },
    {
      name    = "sip",
      record  = "sipdir.online.lync.com.",
      isAlias = false
    },
    {
      name    = "www",
      record  = "matthewjwhite.co.uk.",
      isAlias = false
    },
    {
      name    = "dev",
      record  = data.terraform_remote_state.web-server.outputs.dev-swa
      isAlias = false
    }

  ]
  mx-records = [
    {
      name = "@"
      ttl  = 3600
      records = [
        {
          preference = 0
          exchange   = "matthewjwhite-co-uk.mail.protection.outlook.com."
        }
      ]
    }
  ]
  ns-records = [
    {
      name = "tfttest"
      ttl  = 300
      records = [
        "ns1-03.azure-dns.com.",
        "ns2-03.azure-dns.net.",
        "ns3-03.azure-dns.org.",
        "ns4-03.azure-dns.info."
      ]
    }
  ]
  ptr-records = []
  srv-records = []
  txt-records = [
    {
      name    = "_dmarc",
      records = ["v=DMARC1; p=quarantine; pct=50; rua=mailto:dmarc@matthewjwhite.co.uk; ruf=mailto:dmarc@matthewjwhite.co.uk; fo=1"]
    },
    {
      name    = "_dnsauth.fd",
      records = ["gjjyl16msb6l95zvjnhxv1nzf6ldxsck"]
    },
    {
      name    = "_dnsauth.fdoor",
      records = ["5j22clbbcf3gzs95t92xr14ykh1s0jdl"]
    },
    {
      name    = "asuid.newsite",
      records = ["785BB65719041BA0A0ED39A14A41CC881653B01532783F9507B0C31FF2F54432"]
    },
    {
      name = "@",
      records = [
        "v=spf1 include:spf.protection.outlook.com a:www.matthewjwhite.co.uk -all",
        "MS=ms65196555",
        "google-site-verification=1UJCslKGjOU26wgnB_rnNY9WyQaXxxyNRHQxQqxFBPY",
        "ms-domain-verification=d8300c96-c9ba-4569-a0f9-469cbc585614",
        data.terraform_remote_state.web-server.outputs.mjw-dns-txt
      ]
      ttl = 600
    }
  ]
}

module "mjw-mtasts" {
  source                   = "./module/mtasts"
  use-existing-cdn-profile = true
  existing-cdn-profile     = azurerm_cdn_profile.cdn-mta-sts.name
  cdn-resource-group       = azurerm_resource_group.cdnprofiles.name
  dns-resource-group       = azurerm_resource_group.dnszones.name
  stg-resource-group       = "RG-WhiteFam-UKS"
  mx-records               = ["matthewjwhite-co-uk.mail.protection.outlook.com"]
  domain-name              = azurerm_dns_zone.matthewjwhite-co-uk.name
  depends_on               = [azurerm_resource_group.cdnprofiles, azurerm_resource_group.dnszones]
  reporting-email          = "tls-reports@matthewjwhite.co.uk"
  resource-prefix          = "mjw"
  tags                     = local.tags
  permitted-ips            = local.permitted_ips
}
```
