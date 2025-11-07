###########################################
# 🔹 Azure Provider + Resources
###########################################
provider "azurerm" {
  features {}

  use_oidc        = true

  # Use these only if you're NOT running in GitHub Actions OIDC mode
  #client_id     = var.client_id != "" ? var.client_id : null
  #client_secret = var.client_secret != "" ? var.client_secret : null
}

locals {
  candidate_regions = [
    "centralindia",
    "southindia",
    "eastus2",
    "westeurope"
  ]

  chosen_region = local.candidate_regions[var.region_index]
}

# -----------------------------
# Azure Resource Group
# -----------------------------
resource "azurerm_resource_group" "t" {
  name     = "rg-2023mt03505-t"
  location = local.chosen_region
}

# -----------------------------
# Azure Storage Account
# -----------------------------
resource "azurerm_storage_account" "sa" {
  name                     = lower("st2023mt03505${var.region_index}")
  resource_group_name      = azurerm_resource_group.t.name
  location                 = azurerm_resource_group.t.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = {
    Project = "MTechDrift"
    Environment = "Test"
  }
}

# -----------------------------
# Azure Storage Container
# -----------------------------
resource "azurerm_storage_container" "secure_container" {
  name                  = "secure-container"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

# -----------------------------
# Azure Network Security Group
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

###########################################
# 🔹 Azure Outputs
###########################################
output "azure_resources" {
  value = {
    resource_group      = azurerm_resource_group.t.name
    storage_account     = azurerm_storage_account.sa.name
    storage_container   = azurerm_storage_container.secure_container.name
    network_security_group = azurerm_network_security_group.secure_nsg.name
  }
}
