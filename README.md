# APIM AI Gateway — Sandbox

An Azure API Management (Developer tier) AI Gateway, built as flat Terraform (no modules) in a single subscription. It gives developer teams a **governed front door** to in-house AI: central managed-identity auth, token quotas, semantic caching, prompt safety, MCP governance, and an agent/API catalog. All capabilities are provisioned together by a single `terraform apply` (this sandbox mirrors a production deployment) — there are no enable/disable toggles.

**Architecture diagram:** [View on Excalidraw](https://excalidraw.com/#json=bbH-Z8I4Tv6xxYNUCXyPT,AE-7r1A3yYIl4mTrjqvWFQ)

The diagram shows client dev-team apps (Team Alpha / Team Beta) calling APIM via per-team subscription keys, the full inbound/outbound policy chain, and the backends: Azure OpenAI (gpt-4o + text-embedding-3-small), Azure AI Content Safety, Azure Managed Redis, governed MCP server, and Azure API Center + Developer Portal. Telemetry flows to Application Insights and Log Analytics.

---

## Prerequisites

| Requirement | Detail |
|---|---|
| Terraform | >= 1.9 |
| Azure CLI | `az login` then `az account set --subscription <id>` |
| Resource providers | `Microsoft.ApiManagement`, `Microsoft.CognitiveServices`, `Microsoft.Cache`, `Microsoft.ApiCenter` |

Register providers if not already active:

```bash
az provider register --namespace Microsoft.ApiManagement
az provider register --namespace Microsoft.CognitiveServices
az provider register --namespace Microsoft.Cache
az provider register --namespace Microsoft.ApiCenter
```

---

## Capabilities

A single `terraform apply` provisions **all** of the following. Use the `test/` scripts to validate each capability after apply.

| Capability | Resources / policies | Validate with |
|---|---|---|
| **Foundation + observability** | RG, Log Analytics, App Insights, APIM Developer_1, AOAI (gpt-4o + text-embedding-3-small), system-assigned MI + RBAC, LLM API, per-team Products + Subscriptions | `test/01-chat.sh` — chat completion succeeds; request visible in App Insights |
| **Cost & fairness** | `llm-token-limit` (TPM + monthly quota), `llm-emit-token-metric`, circuit breaker on AOAI backend, retry policy | `test/02-token-limit.sh` — rapid requests return HTTP 429; `llm-metrics` visible in App Insights |
| **Semantic caching** | Azure Managed Redis (Balanced_B3, RediSearch), APIM external cache, `llm-semantic-cache-lookup` + `llm-semantic-cache-store` | `test/03-cache.sh` — second identical prompt is faster; fewer backend tokens |
| **Prompt safety** | Azure AI Content Safety account + backend + MI RBAC, `llm-content-safety` policy | `test/04-content-safety.sh` — benign prompt passes (200); harmful prompt blocked (403) |
| **MCP governance** | Governed external MCP server via `azapi` (ARM `2025-09-01-preview`), `mcp-governance.xml` (rate-limit + ip-filter) | `test/05-mcp.sh` — add MCP endpoint in VS Code agent mode; list and invoke a tool |
| **Agents + self-service** | Azure API Center service (stable ARM `2024-03-01`); Developer Portal. A2A agent API: **manual portal step** (see Known Limitations) | API Center service exists; team discovers + subscribes via Developer Portal |

The LLM capabilities are composed into one always-on API policy (`policies/llm-gateway.xml`): managed-identity auth → content safety → token limit → token metrics → semantic-cache lookup, with retry on the backend and semantic-cache store on the outbound.

---

## Apply runbook

### Setup

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set publisher_email to your address.
# Optionally change location (default: uksouth) — verify gpt-4o GlobalStandard
# quota is available in your chosen region before applying.
# Optionally set existing_mcp_server_url to the MCP server you want to govern.

terraform init
```

### Apply (provisions everything)

```bash
terraform apply
```

> APIM Developer tier provisioning takes **30–45 minutes** and Azure Managed Redis **~10–15 minutes**; a clean apply is dominated by these. Wait until apply completes before running tests.

### Retrieve outputs and set test env vars

```bash
export GATEWAY_URL=$(terraform output -raw apim_gateway_url)
export SUB_KEY=$(terraform output -json team_subscription_keys | jq -r '.["team-alpha"]')
export DEPLOYMENT=$(terraform output -raw chat_deployment_name)   # gpt-4o
```

### Validate each capability

```bash
chmod +x test/*.sh
./test/01-chat.sh              # chat completion JSON; request appears in App Insights
./test/02-token-limit.sh      # eventually HTTP 429; llm-metrics in App Insights
./test/03-cache.sh            # second identical prompt is faster; fewer backend tokens
./test/04-content-safety.sh   # benign -> 200; harmful -> 403
./test/05-mcp.sh              # prints MCP endpoint + key header to add in VS Code agent mode
```

### Developer Portal + A2A agent (manual)

The Developer Portal ships with the Developer tier (no Terraform resource):

1. Azure portal → your APIM instance → **Developer portal** → **Publish**.
2. Share the portal URL so teams can discover and subscribe to products.

The A2A agent API has no ARM/azapi shape yet, so register it manually (see Known Limitations): APIM → **APIs → + Add API → A2A Agent**. It then auto-syncs into the API Center catalog.

---

## RBAC

APIM's system-assigned managed identity receives the following role assignments (applied by Terraform — no manual steps):

| Identity | Role | Scope |
|---|---|---|
| APIM system-assigned MI | **Cognitive Services OpenAI User** | Azure OpenAI account |
| APIM system-assigned MI | **Cognitive Services User** | Azure AI Content Safety account |

This is what allows APIM policy to call `authentication-managed-identity` against the AOAI and Content Safety backends without storing any credentials.

---

## Known limitations / preview flags

**(a) A2A agent API is portal-only today.**
The ARM/azapi shape for importing an A2A agent API (`apiType: a2a`) does not exist in the `Microsoft.ApiManagement/service/apis` schema as of 2026-05-30 — the ARM reference restricts `apiType` to `graphql | grpc | http | odata | soap | websocket`. The feature is documented as a portal-only flow only ("APIs → + Add API → A2A Agent tile"). See the detailed TODO comment in `agents-apicenter.tf`. Re-evaluate when Microsoft publishes an ARM type/properties for A2A.

**(b) MCP scenario: govern only, not expose.**
Only the "govern an existing remote MCP server" scenario is implemented (`mcp.tf`). The "expose a sample REST API as an MCP server" scenario is not implemented. The ARM body for the external-passthrough case uses `serviceUrl` + `mcpProperties` per the `2025-09-01-preview` schema — see the honesty note in `mcp.tf` for the caveat.

**(c) Per-team TPM/quota is not enforced per-team.**
`var.teams` defines `tokens_per_minute` and `monthly_quota` per team, but the API-scope `llm-token-limit` policy uses a single representative limit (`local.default_tpm` = 2000, `local.default_quota` = 2000000) keyed on subscription ID. To enforce different limits per team, move the token-limit policy to the product scope (one product policy per team). This is a deliberate sandbox simplification.

**(d) Preview features.**
- MCP server resource: `Microsoft.ApiManagement/service/apis@2025-09-01-preview`
- A2A agent API: portal-only, no stable ARM shape
- AI gateway in Azure AI Foundry: out of scope for this sandbox

**(e) gpt-4o GlobalStandard quota.**
`gpt-4o` with `GlobalStandard` SKU may not have quota in all regions or subscriptions. `terraform plan` will not surface this — only `terraform apply` (deployment creation) will fail. If you see a quota error, either request quota for the region, change `chat_model.sku_name` to `Standard` and lower `capacity`, or choose a different region in `terraform.tfvars`.

---

## Production-hardening appendix

The following are **deliberately out of scope** for this sandbox. Each entry includes a one-line pointer to how it would be added.

| Capability | How to add for production |
|---|---|
| **VNet injection / internal mode** | Set `virtual_network_type = "Internal"` on `azurerm_api_management` and provide a delegated subnet; add `azurerm_subnet_network_security_group_association` with APIM NSG rules. |
| **Application Gateway + WAF in front** | Deploy `azurerm_application_gateway` with WAF v2 SKU pointing at the APIM internal VIP; route public ingress through it. |
| **Private endpoints + private DNS zones** | Add `azurerm_private_endpoint` + `azurerm_private_dns_zone` / `_zone_virtual_network_link` for AOAI, Content Safety, Redis, and API Center. |
| **Key Vault for named values / secrets** | Create `azurerm_key_vault` + secrets; reference them as `azurerm_api_management_named_value` with `secret = true` and `value_from_key_vault { secret_id = ... }` instead of inline strings. |
| **Multi-region + zone redundancy** | Upgrade to Premium tier; add `additional_location` blocks; enable `zones = ["1","2","3"]`. Developer tier does not support zones or additional locations. |
| **Premium / StandardV2 tier** | Change `sku_name = "Developer_1"` to `"Premium_1"` (or `"StandardV2_1"`) in `apim.tf`; re-provision. |
| **CI/CD pipeline** | Add a GitHub Actions or Azure DevOps pipeline with `terraform fmt -check`, `terraform validate`, `terraform plan` (PR gate), `terraform apply` (main merge). Store the service-principal credentials as pipeline secrets. |
| **Remote Terraform state backend** | Add a `backend "azurerm" { ... }` block to `providers.tf`; provision an Azure Storage account + container for state; run `terraform init -migrate-state`. |
| **Defender for APIs** | Enable Microsoft Defender for APIs on the APIM instance via `azurerm_security_center_subscription_pricing` (plan `Apis`) and onboard the API inventory. |
