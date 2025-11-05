terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
  }
}

provider "azurerm" {
  features {}
}

# ====================
# Resource Group
# ====================

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.azure_location

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# ====================
# Azure OpenAI Account (Cognitive Services)
# ====================

resource "azurerm_cognitive_account" "aoai" {
  name                = var.cognitive_account_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  kind     = "OpenAI"
  sku_name = var.cognitive_sku

  public_network_access_enabled = var.public_network_access_enabled

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# ====================
# Azure OpenAI Deployment
# ====================

resource "azurerm_cognitive_deployment" "gpt4omini" {
  name                 = var.deployment_name
  cognitive_account_id = azurerm_cognitive_account.aoai.id

  model {
    format  = "OpenAI"
    name    = var.model_name
    version = var.model_version
  }

  scale {
    type     = var.deployment_sku
    capacity = var.deployment_capacity
  }
}
