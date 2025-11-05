# ====================
# Resource Group Outputs
# ====================

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.this.name
}

output "resource_group_location" {
  description = "Resource group location"
  value       = azurerm_resource_group.this.location
}

# ====================
# Azure OpenAI Account Outputs
# ====================

output "aoai_endpoint" {
  description = "Azure OpenAI endpoint URL (use for AZURE_OPENAI_ENDPOINT)"
  value       = azurerm_cognitive_account.aoai.endpoint
}

output "aoai_primary_key" {
  description = "Azure OpenAI primary key (use for AZURE_OPENAI_KEY)"
  value       = azurerm_cognitive_account.aoai.primary_access_key
  sensitive   = true
}

output "aoai_secondary_key" {
  description = "Azure OpenAI secondary key"
  value       = azurerm_cognitive_account.aoai.secondary_access_key
  sensitive   = true
}

output "aoai_account_id" {
  description = "Azure OpenAI account ID"
  value       = azurerm_cognitive_account.aoai.id
}

# ====================
# Deployment Outputs
# ====================

output "deployment_name" {
  description = "Azure OpenAI deployment name (use for AZURE_OPENAI_DEPLOYMENT)"
  value       = azurerm_cognitive_deployment.gpt4omini.name
}

output "deployment_id" {
  description = "Azure OpenAI deployment ID"
  value       = azurerm_cognitive_deployment.gpt4omini.id
}

output "model_name" {
  description = "Deployed model name"
  value       = var.model_name
}

output "model_version" {
  description = "Deployed model version"
  value       = var.model_version
}

output "api_version" {
  description = "API version (use for AZURE_OPENAI_API_VERSION)"
  value       = var.api_version
}

# ====================
# Environment Variables for .env
# ====================

output "env_vars" {
  description = "Environment variables for application .env file"
  value = {
    AZURE_OPENAI_ENDPOINT    = azurerm_cognitive_account.aoai.endpoint
    AZURE_OPENAI_DEPLOYMENT  = azurerm_cognitive_deployment.gpt4omini.name
    AZURE_OPENAI_API_VERSION = var.api_version
  }
}

output "env_vars_sensitive" {
  description = "Sensitive environment variables (API key)"
  value = {
    AZURE_OPENAI_KEY = azurerm_cognitive_account.aoai.primary_access_key
  }
  sensitive = true
}
