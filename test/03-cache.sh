#!/usr/bin/env bash
# Sends the same prompt twice; the second should be faster / served from cache.
set -euo pipefail
: "${GATEWAY_URL:?}" "${SUB_KEY:?}" "${DEPLOYMENT:?}"
payload='{"messages":[{"role":"user","content":"What is the capital of France?"}],"max_tokens":30}'
for i in 1 2; do
  echo "--- request $i ---"
  curl -sS -w "\ntime_total=%{time_total}s\n" -X POST \
    "${GATEWAY_URL}/openai/deployments/${DEPLOYMENT}/chat/completions?api-version=2024-10-21" \
    -H "Content-Type: application/json" \
    -H "Ocp-Apim-Subscription-Key: ${SUB_KEY}" \
    -d "${payload}"
done
echo "Expect request 2 to be faster (cache hit). Confirm reduced backend tokens in App Insights."
