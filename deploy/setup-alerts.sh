#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-alerts.sh — Configure Azure Monitor alerts on production App Insights
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.production"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Missing $ENV_FILE — run setup-infra.sh first" >&2
  exit 1
fi
source "$ENV_FILE"

DAVE_WEBHOOK_URL="${DAVE_WEBHOOK_URL:?Set DAVE_WEBHOOK_URL env var}"

echo "=== Setting up alerts for production ==="
echo "Resource Group: $RESOURCE_GROUP"
echo "App Insights:   $APP_INSIGHTS_NAME"
echo "Webhook:        $DAVE_WEBHOOK_URL"
echo ""

# --- Action Group ---
ACTION_GROUP_NAME="shopfast-dave-ag"
echo "Creating action group: $ACTION_GROUP_NAME"
az monitor action-group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACTION_GROUP_NAME" \
  --short-name "DaveAlert" \
  --action webhook dave-webhook "$DAVE_WEBHOOK_URL" \
  -o none

ACTION_GROUP_ID=$(az monitor action-group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACTION_GROUP_NAME" \
  --query id -o tsv)

# Get App Insights resource ID
AI_RESOURCE_ID=$(az monitor app-insights component show \
  --app "$APP_INSIGHTS_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id -o tsv)

# --- Scheduled Query Alert: >3 failed requests (5xx) in 5 min ---
echo "Creating alert: High 5xx Error Rate"
az monitor scheduled-query create \
  --resource-group "$RESOURCE_GROUP" \
  --name "shopfast-high-5xx-errors" \
  --display-name "ShopFast: High 5xx Error Rate" \
  --scopes "$AI_RESOURCE_ID" \
  --condition "count 'requests | where resultCode startswith \"5\"' > 3" \
  --condition-query "requests | where resultCode startswith '5'" \
  --evaluation-frequency 1m \
  --window-size 5m \
  --severity 1 \
  --action-groups "$ACTION_GROUP_ID" \
  --description "More than 3 failed requests (5xx) in 5 minutes" \
  -o none 2>/dev/null || {
    # Fallback: use ARM-style if the shorthand doesn't work
    az monitor scheduled-query create \
      --resource-group "$RESOURCE_GROUP" \
      --name "shopfast-high-5xx-errors" \
      --display-name "ShopFast: High 5xx Error Rate" \
      --scopes "$AI_RESOURCE_ID" \
      --condition "count > 3 where TimeGenerated > ago(5m)" \
      --condition-query "requests | where toint(resultCode) >= 500" \
      --evaluation-frequency 1m \
      --window-size 5m \
      --severity 1 \
      --action-groups "$ACTION_GROUP_ID" \
      -o none
  }

# --- Scheduled Query Alert: >2 exceptions in 5 min ---
echo "Creating alert: High Exception Rate"
az monitor scheduled-query create \
  --resource-group "$RESOURCE_GROUP" \
  --name "shopfast-high-exceptions" \
  --display-name "ShopFast: High Exception Rate" \
  --scopes "$AI_RESOURCE_ID" \
  --condition "count 'exceptions' > 2" \
  --condition-query "exceptions" \
  --evaluation-frequency 1m \
  --window-size 5m \
  --severity 1 \
  --action-groups "$ACTION_GROUP_ID" \
  --description "More than 2 exceptions in 5 minutes" \
  -o none 2>/dev/null || {
    az monitor scheduled-query create \
      --resource-group "$RESOURCE_GROUP" \
      --name "shopfast-high-exceptions" \
      --display-name "ShopFast: High Exception Rate" \
      --scopes "$AI_RESOURCE_ID" \
      --condition "count > 2 where TimeGenerated > ago(5m)" \
      --condition-query "exceptions" \
      --evaluation-frequency 1m \
      --window-size 5m \
      --severity 1 \
      --action-groups "$ACTION_GROUP_ID" \
      -o none
  }

# --- Metric Alert: Response time > 5000ms ---
echo "Creating alert: Slow Response Time"
az monitor metrics alert create \
  --resource-group "$RESOURCE_GROUP" \
  --name "shopfast-slow-response" \
  --description "Response time exceeds 5000ms" \
  --scopes "$AI_RESOURCE_ID" \
  --condition "avg requests/duration > 5000" \
  --evaluation-frequency 1m \
  --window-size 5m \
  --severity 2 \
  --action "$ACTION_GROUP_ID" \
  -o none

echo ""
echo "✅ All alerts configured!"
echo "   - High 5xx Error Rate (>3 in 5min)"
echo "   - High Exception Rate (>2 in 5min)"
echo "   - Slow Response Time (>5000ms avg)"
echo "   - All alerting → Dave webhook"
