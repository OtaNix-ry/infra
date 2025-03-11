terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "=3.0.0"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "=3.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "=4.0.0"
    }
  }
}

locals {
  resource_group_location = "northeurope"
  hostname                = "otanix-vm"
}

provider "azurerm" {
  features {}
  subscription_id = "1ced546c-3a27-4e85-8878-f48cd8e23130"
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

resource "azurerm_dns_txt_record" "github_organization_challenge" {
  name                = "_gh-OtaNix-ry-o"
  resource_group_name = azurerm_resource_group.dns_rg.name
  zone_name           = azurerm_dns_zone.dns_zone.name
  ttl                 = 300

  record {
    value = "cd376abbac"
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

resource "azurerm_resource_group" "vm_rg" {
  name     = "vm-rg"
  location = local.resource_group_location
}

resource "azurerm_virtual_network" "vm" {
  name                = "vm-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.vm_rg.location
  resource_group_name = azurerm_resource_group.vm_rg.name
}

resource "azurerm_subnet" "vm" {
  name                 = "vm"
  resource_group_name  = azurerm_resource_group.vm_rg.name
  virtual_network_name = azurerm_virtual_network.vm.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "vm-pip"
  resource_group_name = azurerm_resource_group.vm_rg.name
  location            = azurerm_resource_group.vm_rg.location
  allocation_method   = "Static"
  domain_name_label   = local.hostname
}

resource "azurerm_network_interface" "vm" {
  name                = "vm-nic"
  location            = azurerm_resource_group.vm_rg.location
  resource_group_name = azurerm_resource_group.vm_rg.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_security_group" "vm" {
  name                = "vm"
  location            = azurerm_resource_group.vm_rg.location
  resource_group_name = azurerm_resource_group.vm_rg.name
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

resource "azurerm_network_security_rule" "http" {
  name                        = "http"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.vm_rg.name
  network_security_group_name = azurerm_network_security_group.vm.name
}

resource "azurerm_network_security_rule" "https" {
  name                        = "https"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.vm_rg.name
  network_security_group_name = azurerm_network_security_group.vm.name
}

resource "azurerm_network_security_rule" "ssh_inbound" {
  name                        = "sshin"
  priority                    = 102
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.vm_rg.name
  network_security_group_name = azurerm_network_security_group.vm.name
}

resource "azurerm_network_security_rule" "ssh_outbound" {
  name                        = "sshout"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.vm_rg.name
  network_security_group_name = azurerm_network_security_group.vm.name
}

resource "azurerm_managed_disk" "nixos-image" {
  # TODO: should probably be imported with terraform import
  name                 = "nixos-image"
  location             = local.resource_group_location
  resource_group_name  = "vm-img-rg"
  storage_account_type = "Premium_LRS"
  hyper_v_generation   = "V2"

  # https://github.com/hashicorp/terraform-provider-azurerm/issues/17792
  create_option = "Empty"
  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_image" "nixos-image" {
  # TODO: should probably be imported with terraform import
  name                = "nixos-image"
  location            = local.resource_group_location
  resource_group_name = "vm-img-rg"
  hyper_v_generation  = "V2"

  os_disk {
    caching         = "ReadOnly"
    managed_disk_id = azurerm_managed_disk.nixos-image.id
    os_state        = "Generalized"
    os_type         = "Linux"
    storage_type    = "Premium_LRS"
  }

  timeouts {}

  lifecycle {
    ignore_changes = [
      os_disk,
      timeouts
    ]
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "otanix-vm"
  location            = local.resource_group_location
  resource_group_name = azurerm_resource_group.vm_rg.name
  # TODO: figure out how to create a custom NVMe image in order to use a cheaper size
  size = "Standard_DC4as_cc_v5"

  network_interface_ids = [azurerm_network_interface.vm.id]

  admin_username = "otanix"
  admin_ssh_key {
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCiDxF/PZcYfX6N3CQOdQdW0PTPN7tgmwL6RPFDBlJURsxiTlmlRygjMVjrnxbIN9KGIP2p3hUKxensm0ftbl3fvdBG3nUnreGZAUQ7prSrli3tv+WITPFdONtDqcrMlYXbBy51/kFLUQMV7wBYurM/4bW/BOXtNZdk8/dLyCqAr1ynZmXFFHEB3APtlxaLlsyHEER5Nj7WDlxpFUxOqzasPg8MMGKQeN+d2TbUq1s0YDVwmk4F+Zqfj0H9AAYYt4zkiKbCkzTrJXk9snBPAyUot8jkAjZW5nu7quVoiHvWY3335iaa4o2JWDkm6/QEXYzKIbi865jOr3A5DRFytNFQJ7nmXfSNWAJmblSlatlszQLwmTLP5wkV+3zbRHv7WuvWivR76Xy0uyK331UvqrRbNha+EbVoWP5DyFnichBH7B/IgHkLHQJIuYiQBZ2ZwTuVpEoxyCUyl9acDtmUZvuomTAEjLRQElnhRo8iyDf92dl19Q9dG/1RWqLXUEDVBcLrlk89aEnIk7DuwvmVWzWM+On9S8ojH04TgRJM5ZkbQLAIqW5AkLqY6CP5Gzknsh7F4fl5Mq0FZlCOtFzxR+YgIn4IGndonm8/iqDQjJNOWVysFdNRPisPSR5AO5TiuxZSOcCuRkS56cZTHKjdqZS8CxiCfs2ZPlzMnzKJSNDXxQ=="
    username   = "otanix"
  }

  source_image_id = azurerm_image.nixos-image.id

  os_disk {
    caching              = "ReadOnly"
    storage_account_type = "Premium_LRS"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [azurerm_image.nixos-image]
}
