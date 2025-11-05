# ====================
# General Settings
# ====================

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "poc-mc-vision"
}

variable "azure_location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus2"
}

# ====================
# Resource Group Settings
# ====================

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "rg-aoai-poc"
}

# ====================
# Cognitive Services (Azure OpenAI) Settings
# ====================

variable "cognitive_account_name" {
  description = "Azure OpenAI (Cognitive Services) account name"
  type        = string
  default     = "aoai-poc-vision-eastus2"
}

variable "cognitive_sku" {
  description = "Cognitive Services SKU"
  type        = string
  default     = "S0"
}

variable "public_network_access_enabled" {
  description = "Enable public network access"
  type        = bool
  default     = true
}

# ====================
# Azure OpenAI Deployment Settings
# ====================

variable "deployment_name" {
  description = "Azure OpenAI deployment name"
  type        = string
  default     = "gpt4omini-poc"
}

variable "model_name" {
  description = "OpenAI model name"
  type        = string
  default     = "gpt-4o-mini"
}

variable "model_version" {
  description = "OpenAI model version"
  type        = string
  default     = "2024-07-18"
}

variable "deployment_sku" {
  description = "Deployment SKU (pricing tier)"
  type        = string
  default     = "Standard"
}

variable "deployment_capacity" {
  description = "Deployment capacity (required but pay-per-request billing)"
  type        = number
  default     = 1
}

variable "api_version" {
  description = "API version used by application"
  type        = string
  default     = "2024-10-21"
}
