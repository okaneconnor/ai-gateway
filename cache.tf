# Phase 3: Redis semantic cache + APIM external cache wiring.
#
# Schema notes (verified against hashicorp/azurerm latest, 2026-05-30):
#   azurerm_redis_enterprise_cluster / azurerm_redis_enterprise_database are DEPRECATED in
#   azurerm >= 4.x in favour of azurerm_managed_redis (GA in 4.74).  This file uses
#   azurerm_managed_redis accordingly.
#
#   Confirmed attribute names used below:
#     - hostname            : azurerm_managed_redis.<name>.hostname
#     - primary_access_key  : azurerm_managed_redis.<name>.default_database[0].primary_access_key
#     - port (dynamic)      : azurerm_managed_redis.<name>.default_database[0].port
#       (Enterprise / Managed Redis listens on port 10000 by default; referencing the
#        exported port attribute rather than hard-coding 10000 ensures accuracy.)
#     - RediSearch module   : enabled via module { name = "RediSearch" } inside default_database
#     - client_protocol     : "Encrypted" (TLS — required for semantic/vector cache in APIM)
#     - clustering_policy   : "EnterpriseCluster" (required when using RediSearch with APIM)

resource "azurerm_managed_redis" "semantic" {
  count               = var.enable_semantic_cache ? 1 : 0
  name                = local.redis_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  # Balanced_B3 is the smallest SKU that supports modules and geo-replication.
  sku_name = "Balanced_B3"

  default_database {
    # access_keys_authentication_enabled = true is required for primary_access_key to be populated.
    access_keys_authentication_enabled = true
    client_protocol                    = "Encrypted"
    clustering_policy                  = "EnterpriseCluster"

    module {
      name = "RediSearch"
    }
  }
}

resource "azurerm_api_management_redis_cache" "semantic" {
  count             = var.enable_semantic_cache ? 1 : 0
  name              = "semantic-cache"
  api_management_id = azurerm_api_management.apim.id

  # connection_string format: <hostname>:<port>,password=<key>,ssl=True,abortConnect=False
  # Confirmed attributes: hostname (cluster-level), default_database[0].port,
  # default_database[0].primary_access_key (requires access_keys_authentication_enabled = true).
  connection_string = "${azurerm_managed_redis.semantic[0].hostname}:${azurerm_managed_redis.semantic[0].default_database[0].port},password=${azurerm_managed_redis.semantic[0].default_database[0].primary_access_key},ssl=True,abortConnect=False"

  redis_cache_id = azurerm_managed_redis.semantic[0].id
  cache_location = "default"
}
