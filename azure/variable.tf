variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "client_id" {
  description = "Service principal client ID"
  type        = string
}

variable "client_secret" {
  description = "Service principal client secret"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "region_index" {
  description = "Index of the region to use from candidate list"
  type        = number
  default     = 0
}
