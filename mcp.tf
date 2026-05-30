# =============================================================================
# Phase 5 — MCP governance (azapi)
# =============================================================================
#
# CONFIRMED ARM SHAPE (verified against the live Microsoft ARM reference):
#
#   Resource type : Microsoft.ApiManagement/service/apis
#   API version   : 2025-09-01-preview   (mcp support also present in 2025-03-01-preview)
#   azapi type    : "Microsoft.ApiManagement/service/apis@2025-09-01-preview"
#
# In API Management an MCP server is modeled as an *API* whose `apiType` / `type`
# is "mcp". For the "expose & govern an EXISTING remote MCP server" scenario the
# remote server's base URL is placed in `properties.serviceUrl`, the transport is
# Streamable HTTP (`properties.mcpProperties.transportType = "streamable"`), and
# `properties.path` is the route prefix that becomes the public tool path.
#
# Doc URLs used to confirm this:
#   - https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server
#   - https://learn.microsoft.com/azure/api-management/export-rest-mcp-server
#   - https://learn.microsoft.com/azure/api-management/mcp-server-overview
#   - https://learn.microsoft.com/azure/templates/microsoft.apimanagement/2025-09-01-preview/service/apis
#     (ARM reference — `apiType: 'mcp'`, `McpProperties`, `McpEndpoint`,
#      `transportType: 'sse' | 'streamable'`)
#
# IMPORTANT HONESTY NOTE — partially-confirmed body:
#   The ARM reference confirms the resource TYPE, API VERSION, the `mcp` apiType,
#   and the `mcpProperties.transportType`/`endpoints` schema. What the public ARM
#   reference does NOT show is a concrete, deployable example of wiring an EXTERNAL
#   passthrough MCP server (the portal "Expose an existing MCP server" flow is the
#   only first-party documented path, and it does not publish the exact JSON body).
#   In particular it is not 100% documented whether the external server URL is set
#   via `serviceUrl` alone or via a separate backend association. The block below
#   uses `serviceUrl` + `mcpProperties` per the schema, with schema_validation_enabled
#   = false so azapi does not reject preview-only fields. If `terraform apply` is
#   rejected by the control plane, switch to the documented CLI/REST fallback at the
#   bottom of this file (it is commented out, not deleted).
# =============================================================================

resource "azapi_resource" "existing_mcp" {
  type      = "Microsoft.ApiManagement/service/apis@2025-09-01-preview"
  name      = "governed-mcp"
  parent_id = azurerm_api_management.apim.id

  body = {
    properties = {
      displayName = "Governed external MCP server"
      # Route prefix for the MCP tools. Public endpoint becomes:
      #   <gateway-url>/mytools/mcp   (Streamable HTTP transport).
      path = "mytools"

      # MCP API type (confirmed enum value in 2025-xx preview ARM schema).
      apiType = "mcp"

      protocols = ["https"]

      # Backend = the existing remote MCP server we are governing.
      serviceUrl = var.existing_mcp_server_url

      subscriptionRequired = true

      # Streamable HTTP is the default/recommended transport for remote MCP.
      mcpProperties = {
        transportType = "streamable"
      }
    }
  }

  # Preview ARM type — let the control plane validate the body, not the local
  # azapi schema cache (which may lag preview API versions).
  schema_validation_enabled = false
}

# -----------------------------------------------------------------------------
# MCP governance policy.
#
# Attaches policies/mcp-governance.xml (rate-limit-by-key + ip-filter) to the
# governed MCP API. API Management applies API-scope MCP policies to every tool
# exposed by the server.
#
# NOTE: APIM caution — do NOT read context.Response.Body inside MCP policies; it
# triggers response buffering and breaks the Streamable HTTP transport. The
# governance fragment here only does inbound rate-limiting + IP filtering, so it
# is safe.
# -----------------------------------------------------------------------------
resource "azurerm_api_management_api_policy" "mcp" {
  api_name            = azapi_resource.existing_mcp.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = file("${path.module}/policies/mcp-governance.xml")
}

# =============================================================================
# DOCUMENTED FALLBACK (commented out by design).
#
# If the azapi_resource above is rejected because the external-MCP body shape is
# not accepted by the live (preview) control plane, the supported alternative is
# the portal flow — there is no stable az CLI verb for "expose existing MCP
# server" at time of writing. The closest scriptable path is a direct ARM REST
# PUT against the same type/version, e.g.:
#
# resource "null_resource" "existing_mcp_fallback" {
#   triggers = {
#     mcp_url = var.existing_mcp_server_url
#     apim_id = azurerm_api_management.apim.id
#   }
#
#   provisioner "local-exec" {
#     # Requires `az login` + correct subscription. Uses the same confirmed
#     # type/version as the azapi resource above.
#     command = <<-EOT
#       az rest --method put \
#         --url "https://management.azure.com${azurerm_api_management.apim.id}/apis/governed-mcp?api-version=2025-09-01-preview" \
#         --body '{
#           "properties": {
#             "displayName": "Governed external MCP server",
#             "path": "mytools",
#             "type": "mcp",
#             "protocols": ["https"],
#             "serviceUrl": "${var.existing_mcp_server_url}",
#             "subscriptionRequired": true,
#             "mcpProperties": { "transportType": "streamable" }
#           }
#         }'
#     EOT
#   }
# }
#
# Why this is only a fallback: it is imperative (not tracked in Terraform state),
# requires the Azure CLI on the apply host, and is not idempotent the way an
# azapi_resource is. Prefer the azapi_resource; use this only if the preview body
# shape is rejected.
# =============================================================================
