provider "azurerm" {
  features {}
  subscription_id = "d3680142-57f6-4ea0-88f2-e5429dd4c8c5"
  tenant_id       = "1bce831e-c832-44ba-bd99-7fc78674a840"
  resource_provider_registrations = "none"
}

# Choose candidate regions
variable "region_index" {
  description = "Index of the region to use from candidate list"
  type        = number
  default     = 0
}

locals {
  # Canonical Azure region names
  candidate_regions = [
    "centralindia",
    "southindia",
    "eastus2",
    "westeurope"
  ]

  chosen_region = local.candidate_regions[var.region_index]
}

# -----------------------------
# Resource Group
# -----------------------------
resource "azurerm_resource_group" "t" {
  name     = "rg-2023mt03505-t"
  location = local.chosen_region
}

# -----------------------------
# Storage Account
# -----------------------------
resource "azurerm_storage_account" "sa" {
  # must be globally unique, lowercase, 3–24 chars
  name                     = lower("st2023mt03505${var.region_index}")
  resource_group_name      = azurerm_resource_group.t.name
  location                 = azurerm_resource_group.t.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version          = "TLS1_2"
  
}

# -----------------------------
# Storage Container
# -----------------------------
resource "azurerm_storage_container" "secure_container" {
  name                  = "secure-container"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

# -----------------------------
# Network Security Group
# -----------------------------
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

# -----------------------------
# Outputs
# -----------------------------
output "resource_group" {
  value = azurerm_resource_group.t.name
}

output "storage_account_name" {
  value = azurerm_storage_account.sa.name
}

output "storage_container_name" {
  value = azurerm_storage_container.secure_container.name
}

output "nsg_name" {
  value = azurerm_network_security_group.secure_nsg.name
}
