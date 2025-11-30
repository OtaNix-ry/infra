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

resource "azurerm_dns_a_record" "vm" {
  name                = "vm"
  resource_group_name = azurerm_resource_group.dns_rg.name
  zone_name           = azurerm_dns_zone.dns_zone.name
  ttl                 = 300
  records             = [azurerm_public_ip.nixos_pip.ip_address]
}

resource "azurerm_dns_a_record" "nextcloud" {
  name                = "nextcloud"
  resource_group_name = azurerm_resource_group.dns_rg.name
  zone_name           = azurerm_dns_zone.dns_zone.name
  ttl                 = 300
  records             = [azurerm_public_ip.nixos_pip.ip_address]
}

resource "azurerm_resource_group" "nixos_rg" {
  name     = "nixos-resources"
  location = "North Europe"
}

resource "azurerm_virtual_network" "nixos_vnet" {
  name                = "nixos-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.nixos_rg.location
  resource_group_name = azurerm_resource_group.nixos_rg.name
}

resource "azurerm_subnet" "nixos_subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.nixos_rg.name
  virtual_network_name = azurerm_virtual_network.nixos_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "nixos_pip" {
  name                = "nixos-pip"
  resource_group_name = azurerm_resource_group.nixos_rg.name
  location            = azurerm_resource_group.nixos_rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "nixos_nsg" {
  name                = "nixos-nsg"
  location            = azurerm_resource_group.nixos_rg.location
  resource_group_name = azurerm_resource_group.nixos_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nixos_nic" {
  name                = "nixos-nic"
  location            = azurerm_resource_group.nixos_rg.location
  resource_group_name = azurerm_resource_group.nixos_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.nixos_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nixos_pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nixos_nic_assoc" {
  network_interface_id      = azurerm_network_interface.nixos_nic.id
  network_security_group_id = azurerm_network_security_group.nixos_nsg.id
}

resource "azurerm_linux_virtual_machine" "nixos_vm" {
  name                = "nixos-machine"
  resource_group_name = azurerm_resource_group.nixos_rg.name
  location            = azurerm_resource_group.nixos_rg.location
  
  # You can now use ANY size, including v2/v3
  size                = "Standard_B2s_v2" 
  
  # IMPORTANT: Secure Boot must be OFF for NixOS
  secure_boot_enabled = false
  
  admin_username      = "otanix"
  network_interface_ids = [
    azurerm_network_interface.nixos_nic.id,
  ]

  admin_ssh_key {
    username   = "otanix"
    public_key = file("pubkey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  # Use Modern Ubuntu 22.04 (Gen 2)
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # NOTE: uncomment this to prepare a new host
  # This script prepares Ubuntu so NixOS-Anywhere can connect as root
  #user_data = base64encode(<<-EOF
  #  #!/bin/bash
  #  sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  #  mkdir -p /root/.ssh
  #  cp /home/otanix/.ssh/authorized_keys /root/.ssh/authorized_keys
  #  systemctl restart ssh
  #EOF
  #)
}

output "public_ip" {
  value = azurerm_public_ip.nixos_pip.ip_address
}
