# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
}

provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "myResourceGroup"
  location = "West Europe"
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "myVNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create a subnet
resource "azurerm_subnet" "subnet" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create a network security group
resource "azurerm_network_security_group" "nsg" {
  name                = "myNetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create a network interface
resource "azurerm_network_interface" "nic" {
  name                = "myNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Connect the network security group to the network interface
resource "azurerm_network_interface_security_group_association" "nsg_nic_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create a virtual machine
resource "azurerm_windows_virtual_machine" "vm" {
  name                = "myVM"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

# Install Active Directory Domain Services
resource "azurerm_virtual_machine_extension" "ad_ds_extension" {
  name                       = "ad-ds-extension"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File InstallADDS.ps1"
    }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
      "script": "${base64encode(file("InstallADDS.ps1"))}"
    }
  PROTECTED_SETTINGS
}

#
# Configure Site-to-Site VPN with asymmetric keys
resource "azurerm_public_ip" "vpn_gateway_ip" {
  name                = "vpnGatewayPublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_virtual_network_gateway" "vpn_gateway" {
  name                = "myVPNGateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway_ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway_subnet.id
  }
}

# resource "azurerm_local_network_gateway" "on_prem_gateway" {
#   name                = "myOnPremGateway"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   gateway_address     = "YOUR_ON_PREM_VPN_DEVICE_IP"  # Specify the IP address of your on-premises VPN device
#   address_space       = ["YOUR_ON_PREM_NETWORK_RANGE"] # Specify the address range of your on-premises network
# }

# resource "azurerm_virtual_network_gateway_connection" "vpn_connection" {
#   name                = "myVPNConnection"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name

#   type                       = "IPsec"
#   virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn_gateway.id
#   local_network_gateway_id   = azurerm_local_network_gateway.on_prem_gateway.id

#   shared_key = "YOUR_SHARED_KEY"  #shared key of your on-premises network

#   ipsec_policy {
#     dh_group         = "DHGroup2" # Updated the dh_group value
#     ike_encryption   = "AES256"
#     ike_integrity    = "SHA256"
#     ipsec_encryption = "AES256"
#     ipsec_integrity  = "SHA256"
#     pfs_group        = "PFS2"
#     sa_lifetime      = 28800
#   }
# }

# Bonus tasks

# Setup Azure Site Recovery Manager
resource "azurerm_recovery_services_vault" "recovery_vault" {
  name                = "myRecoveryVault"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
}

resource "azurerm_site_recovery_fabric" "recovery_fabric" {
  name                = "myRecoveryFabric"
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.recovery_vault.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_site_recovery_protection_container" "recovery_container" {
  name                 = "myRecoveryContainer"
  resource_group_name  = azurerm_resource_group.rg.name
  recovery_fabric_name = azurerm_site_recovery_fabric.recovery_fabric.name
  recovery_vault_name  = azurerm_recovery_services_vault.recovery_vault.name
}

resource "azurerm_site_recovery_replication_policy" "recovery_policy" {
  name                                                 = "myRecoveryPolicy"
  resource_group_name                                  = azurerm_resource_group.rg.name
  recovery_vault_name                                  = azurerm_recovery_services_vault.recovery_vault.name
  recovery_point_retention_in_minutes                  = 24 * 60
  application_consistent_snapshot_frequency_in_minutes = 4 * 60
}

# Setup Tiering in Blob Storage for Backups
resource "azurerm_storage_account" "storage_account" {
  name                     = "mystorageaccount"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    cors_rule {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD", "PUT", "PATCH", "DELETE", "OPTIONS"]
      allowed_origins = ["*"]
      exposed_headers = ["*"]
      max_age_in_seconds = 3600
    }
  }
}

resource "azurerm_storage_management_policy" "lifecycle_policy" {
  storage_account_id = azurerm_storage_account.storage_account.id

  rule {
    name    = "move-to-cool-after-30-days"
    enabled = true
    filters {
      blob_types = ["blockBlob"]
      prefix_match = ["backups/"]
    }
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
      }
    }
  }

  rule {
    name    = "move-to-archive-after-90-days"
    enabled = true
    filters {
      blob_types = ["blockBlob"]
      prefix_match = ["backups/"]
    }
    actions {
      base_blob {
        tier_to_archive_after_days_since_modification_greater_than = 90
      }
    }
  }
}

# Test Domain Join from On-Prem Windows 10 VM
resource "azurerm_public_ip" "on_prem_vm_public_ip" {
  name                = "onPremVMPublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "on_prem_vm_nic" {
  name                = "onPremVMNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "onPremVMNicConfiguration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.on_prem_vm_public_ip.id
  }
}

# resource "azurerm_virtual_machine_extension" "on_prem_vm_domain_join" {
#   name                       = "on-prem-vm-domain-join"
#   virtual_machine_id         = azurerm_windows_virtual_machine.on_prem_vm.id
#   publisher                  = "Microsoft.Compute"
#   type                       = "CustomScriptExtension"
#   type_handler_version       = "1.9"
#   auto_upgrade_minor_version = true

#   settings = <<SETTINGS
#     {
#       "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File JoinDomain.ps1 -DomainName ${azurerm_virtual_network.vnet.name}.com -UserName adminuser -Password '${azurerm_windows_virtual_machine.vm.admin_password}'"
#     }
#   SETTINGS

#   protected_settings = <<PROTECTED_SETTINGS
#     {
#       "script": "${base64encode(file("JoinDomain.ps1"))}"
#     }
#   PROTECTED_SETTINGS
# }
