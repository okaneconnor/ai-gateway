output "apim_gateway_url" {
  description = "APIM gateway base URL."
  value       = azurerm_api_management.apim.gateway_url
}

output "team_subscription_keys" {
  description = "Per-team APIM subscription primary keys."
  value       = { for k, s in azurerm_api_management_subscription.team : k => s.primary_key }
  sensitive   = true
}

output "chat_deployment_name" {
  description = "Name of the chat model deployment used in OpenAI API paths."
  value       = azurerm_cognitive_deployment.chat.name
}
