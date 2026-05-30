# Architecture Diagram

## APIM AI Gateway — Sandbox Architecture

**Excalidraw URL:** https://excalidraw.com/#json=bbH-Z8I4Tv6xxYNUCXyPT,AE-7r1A3yYIl4mTrjqvWFQ

**Caption:** Full architecture of the `feat/apim-ai-gateway-sandbox` Terraform configuration. Shows client dev-team apps (Team Alpha / Team Beta) calling Azure API Management (Developer tier, system-assigned managed identity) via per-team subscription keys. The APIM AI Gateway layer displays the full inbound/outbound policy chain (1. MI auth → 2. token-limit → 3. semantic-cache lookup → 4. content-safety → 5. circuit breaker + retry / outbound: 6. cache-store → 7. emit-token-metric → 8. logging). Backends are Azure OpenAI (gpt-4o + text-embedding-3-small), Azure AI Content Safety, Azure Managed Redis (RediSearch, external cache), the governed MCP Server, and Azure API Center + Developer Portal. Telemetry flows to Application Insights and Log Analytics Workspace. Phase-gated elements (Phases 2–6) are colour-coded with dashed arrows; Phase 1 always-on elements use solid arrows. Managed-identity RBAC ("Cognitive Services User") annotations are shown on the AOAI and Content Safety backends.

**Source files (cited):**
- `apim.tf` — APIM Developer_1 instance, system-assigned identity, App Insights logger, diagnostics
- `foundation.tf` — Resource Group, Log Analytics Workspace, Application Insights
- `openai.tf` — Azure OpenAI account (kind=OpenAI), gpt-4o + text-embedding-3-small deployments
- `identity-rbac.tf` — Cognitive Services User RBAC: APIM MI → AOAI
- `api-llm.tf` — LLM API import, AOAI backend, embeddings backend, circuit breaker, API policy (phase-composed)
- `products.tf` — Per-team Products + Subscriptions (Team Alpha, Team Beta)
- `cache.tf` — Azure Managed Redis (Balanced_B3, RediSearch module), APIM external cache wiring (Phase 3)
- `content-safety.tf` — Content Safety account, backend, RBAC (Phase 4)
- `mcp.tf` — Governed external MCP server via azapi (Phase 5)
- `agents-apicenter.tf` — Azure API Center via azapi (Phase 6)
- `variables.tf` — Phase toggle variables (enable_token_governance, enable_semantic_cache, enable_content_safety, enable_mcp, enable_agents_selfservice)
- `locals.tf` — Policy file selection logic (phase-composed openai_api_policy_file)
- `policies/` — llm-foundation.xml, llm-governance.xml, llm-semantic-cache.xml, llm-content-safety.xml, mcp-governance.xml
