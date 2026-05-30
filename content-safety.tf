resource "azurerm_cognitive_account" "content_safety" {
  name                  = local.cs_name
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  kind                  = "ContentSafety"
  sku_name              = "S0"
  custom_subdomain_name = local.cs_name
}

resource "azurerm_api_management_backend" "content_safety" {
  name                = "content-safety-backend"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  protocol            = "http"
  url                 = trimsuffix(azurerm_cognitive_account.content_safety.endpoint, "/")
  resource_id         = azurerm_cognitive_account.content_safety.id

  tls {
    validate_certificate_chain = true
    validate_certificate_name  = true
  }
}

resource "azurerm_role_assignment" "apim_content_safety" {
  scope                = azurerm_cognitive_account.content_safety.id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_api_management.apim.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
