#!/usr/bin/env bash
# Lists tools from the governed MCP endpoint using the MCP Inspector or curl.
# MCP endpoint form: ${GATEWAY_URL}/<base-path>/mcp
set -euo pipefail
: "${GATEWAY_URL:?}" "${SUB_KEY:?}"
echo "Add this MCP server in VS Code (MCP: Add Server -> HTTP):"
echo "  ${GATEWAY_URL}/mytools/mcp"
echo "  header: Ocp-Apim-Subscription-Key: ${SUB_KEY}"
echo "Then in Copilot agent mode, list tools and invoke one."
