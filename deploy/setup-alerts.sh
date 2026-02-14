#!/usr/bin/env bash
set -euo pipefail

# Set up Azure Monitor alerts on production App Insights
# These fire when the buggy v1.1.0 starts crashing on NULL data

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.production"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "✗ Missing .env.production — run setup-demo.sh first"
  exit 1
fi
source "$ENV_FILE"

DAVE_WEBHOOK="${DAVE_WEBHOOK_URL:-https://dave-sre.kindbush-6aff378e.eastus2.azurecontainerapps.io/hooks/wake}"

echo "=== Setting up Production Alerts ==="
echo "App Insights: $AI_NAME"
echo "Webhook: $DAVE_WEBHOOK"
echo ""

AI_ID=$(az monitor app-insights component show -g "$RG" -a "$AI_NAME" --query id -o tsv)
LAW_ID=$(az monitor log-analytics workspace show -g "$RG" -n "$LAW_NAME" --query id -o tsv)

# Action Group → Dave webhook
az monitor action-group create -g "$RG" -n "shopfast-dave-ag" \
  --short-name "DaveAlert" \
  --action webhook dave-webhook "$DAVE_WEBHOOK" \
  -o none
AG_ID=$(az monitor action-group show -g "$RG" -n "shopfast-dave-ag" --query id -o tsv)
echo "✓ Action group: shopfast-dave-ag"

# Alert 1: Failed requests (500s) — fires on the NULL crash
az monitor scheduled-query create -g "$RG" -n "shopfast-prod-500s" \
  --scopes "$AI_ID" \
  --condition "count > 3" \
  --condition-query "AppRequests | where ResultCode startswith '5' | where TimeGenerated > ago(5m)" \
  --evaluation-frequency 1m --window-size 5m \
  --severity 1 --action-groups "$AG_ID" \
  --description "ShopFast production: 500 errors detected" \
  -o none
echo "✓ Alert: shopfast-prod-500s (>3 failures in 5min)"

# Alert 2: Exceptions spike
az monitor scheduled-query create -g "$RG" -n "shopfast-prod-exceptions" \
  --scopes "$AI_ID" \
  --condition "count > 2" \
  --condition-query "AppExceptions | where TimeGenerated > ago(5m)" \
  --evaluation-frequency 1m --window-size 5m \
  --severity 1 --action-groups "$AG_ID" \
  --description "ShopFast production: exception spike" \
  -o none
echo "✓ Alert: shopfast-prod-exceptions (>2 exceptions in 5min)"

echo ""
echo "=== Alerts Ready ==="
echo "When v1.1.0 hits production NULL data → 500s → alert fires → Dave wakes up"
