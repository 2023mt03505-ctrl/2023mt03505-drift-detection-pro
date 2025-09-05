provider "azurerm" {
  features {}
  subscription_id = "792ae578-bb37-478b-8f7e-8fe08c0885c9"
  tenant_id       = "e24ac094-efd8-4a6b-98d5-a129b32a8c9a"
}

# Candidate regions
variable "region_index" {
  description = "Index of the region to use"
  type        = number
  default     = 0 # start with 0, change to 1, 2, 3 if error
}

locals {
  candidate_regions = [
    "Central India",
    "South India",
    "East US 2",
    "West Europe"
  ]
  chosen_region = local.candidate_regions[var.region_index]
}

# Resource Group
resource "azurerm_resource_group" "t" {
  name     = "rg-2023mt03505-t"
  location = local.chosen_region
}

# Storage account
resource "azurerm_storage_account" "sa" {
  name                     = "stor2023mt03505${var.region_index}"
  resource_group_name      = azurerm_resource_group.t.name
  location                 = azurerm_resource_group.t.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Storage container
resource "azurerm_storage_container" "secure_container" {
  name                  = "secure-container"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

# Network Security Group
resource "azurerm_network_security_group" "secure_nsg" {
  name                = "nsg-secure"
  location            = azurerm_resource_group.t.location
  resource_group_name = azurerm_resource_group.t.name

  security_rule {
    name                       = "Deny_SSH_All"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
