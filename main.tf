terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "=3.0.0"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "=3.0.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "=2.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "=4.0.0"
    }
  }
}

locals {
  resource_group_location = "northeurope"
}

provider "azurerm" {
  features {}
}

provider "dns" {}

resource "azurerm_resource_group" "dns_rg" {
  name     = "dns-rg"
  location = local.resource_group_location
}

resource "azurerm_dns_zone" "dns_zone" {
  name                = "otanix.fi"
  resource_group_name = azurerm_resource_group.dns_rg.name
}

resource "azurerm_dns_a_record" "website" {
  name                = "@"
  resource_group_name = azurerm_resource_group.dns_rg.name
  zone_name           = azurerm_dns_zone.dns_zone.name
  ttl                 = 300
  records             = ["185.199.111.153", "185.199.109.153", "185.199.108.153", "185.199.110.153"]
}

resource "azurerm_dns_aaaa_record" "website" {
  name                = "@"
  resource_group_name = azurerm_resource_group.dns_rg.name
  zone_name           = azurerm_dns_zone.dns_zone.name
  ttl                 = 300
  records             = ["2606:50c0:8003::153", "2606:50c0:8002::153", "2606:50c0:8001::153", "2606:50c0:8000::153"]
}

resource "azurerm_dns_cname_record" "www_cname" {
  name                = "www"
  resource_group_name = azurerm_resource_group.dns_rg.name
  zone_name           = azurerm_dns_zone.dns_zone.name
  ttl                 = 300
  record              = azurerm_dns_zone.dns_zone.name
}

resource "azurerm_dns_txt_record" "github_challenge" {
  name                = "_github-pages-challenge-otanix-ry"
  resource_group_name = azurerm_resource_group.dns_rg.name
  zone_name           = azurerm_dns_zone.dns_zone.name
  ttl                 = 300

  record {
    value = "3b6eb1c302b720d942fb26752c5a61"
  }
}

resource "azurerm_dns_mx_record" "mail" {
  name                = "@"
  resource_group_name = azurerm_resource_group.dns_rg.name
  zone_name           = azurerm_dns_zone.dns_zone.name

  record {
    preference = 1
    exchange   = "smtp.google.com."
  }

  ttl = 3600
}

resource "azurerm_resource_group" "otanix_rg" {
  name     = "otanix-rg"
  location = local.resource_group_location
}

resource "azurerm_dns_a_record" "builder_a" {
  name                = "builder"
  resource_group_name = azurerm_resource_group.dns_rg.name
  zone_name           = azurerm_dns_zone.dns_zone.name
  ttl                 = 300
  records             = data.dns_a_record_set.builder_dns_fetch.addrs
}

resource "azurerm_service_plan" "otanix_plan" {
  name                = "otanix-app-service-plan"
  location            = azurerm_resource_group.otanix_rg.location
  resource_group_name = azurerm_resource_group.otanix_rg.name

  os_type  = "Linux"
  sku_name = "P1v3"
}

resource "azurerm_linux_web_app" "builder" {
  name                = "builder-web-app"
  location            = azurerm_resource_group.otanix_rg.location
  resource_group_name = azurerm_resource_group.otanix_rg.name
  service_plan_id     = azurerm_service_plan.otanix_plan.id

  site_config {
    application_stack {
      docker_image     = "ghcr.io/otanix-ry/builder"
      docker_image_tag = "latest"
      #docker_registry_url = "https://ghcr.io"
      #docker_image_name   = "otanix-ry/builder:latest"
    }
  }

  app_settings = {
    WEBSITES_PORT = 22
  }
}

data "dns_a_record_set" "builder_dns_fetch" {
  host = azurerm_linux_web_app.builder.default_hostname
}
