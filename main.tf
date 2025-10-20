###########################################
# 🔹 Azure Provider + Resources
###########################################
provider "azurerm" {
  features {}
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
# 🔹 AWS Provider + Resources
###########################################
provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy"
  type        = string
  default     = "ap-south-1"
}

# -----------------------------
# AWS S3 Storage (like Azure Storage Account)
# -----------------------------
resource "aws_s3_bucket" "storage" {
  bucket        = "st2023mt03505-${var.region_index}"
  force_destroy = true

  # Block all public access
  acl = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Project = "MTechDrift"
  }
}

# -----------------------------
# AWS Security Group (like Azure NSG)
# -----------------------------
variable "vpc_id" {
  description = "Existing VPC ID to attach security group"
  type        = string
}

resource "aws_security_group" "secure_sg" {
  name        = "secure-sg"
  description = "Secure SG with restricted SSH"
  vpc_id      = var.vpc_id

  # Only allow internal SSH (not 0.0.0.0/0)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "MTechDrift"
  }
}

###########################################
# 🔹 Outputs
###########################################
output "azure_resource_group" {
  value = azurerm_resource_group.t.name
}

output "azure_storage_account_name" {
  value = azurerm_storage_account.sa.name
}

output "azure_storage_container_name" {
  value = azurerm_storage_container.secure_container.name
}

output "azure_nsg_name" {
  value = azurerm_network_security_group.secure_nsg.name
}

output "aws_s3_bucket_name" {
  value = aws_s3_bucket.storage.bucket
}

output "aws_security_group_name" {
  value = aws_security_group.secure_sg.name
}
