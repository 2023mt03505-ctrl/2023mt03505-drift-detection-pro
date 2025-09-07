terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100"
    }
  }
  backend "azurerm" {
    resource_group_name   = "rg-2023mt03505-n"
    storage_account_name  = "storag2023mt03505"
    container_name        = "2023mt03505cont"
    key                   = "terraform.tfstate"
    use_oidc              = true  # ✅ must be true for GitHub Actions
  }
}
