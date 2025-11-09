# ==============================
# Azure Variables (Terraform)
# ==============================

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "client_id" {
  description = "Service principal client ID (used for Azure OIDC login)"
  type        = string
}

variable "client_secret" {
  description = "Service principal client secret (sensitive)"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

# Optional region index to pick region from a list
variable "region_index" {
  description = "Index of the region to use from candidate list"
  type        = number
  default     = 0
}
