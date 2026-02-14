#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# deploy-app.sh — Build and deploy ShopFast to an environment
# Usage: ./deploy-app.sh <staging|production> [--slot staging]
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ENV_NAME="${1:?Usage: deploy-app.sh <staging|production> [--slot staging]}"
SLOT=""

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --slot) SLOT="${2:?--slot requires a value}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

ENV_FILE="$SCRIPT_DIR/.env.${ENV_NAME}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Missing $ENV_FILE — run setup-infra.sh first" >&2
  exit 1
fi
source "$ENV_FILE"

echo "=== Deploying ShopFast ==="
echo "Environment: $ENV_NAME"
echo "App:         $APP_NAME"
[[ -n "$SLOT" ]] && echo "Slot:        $SLOT"
echo ""

# --- Build frontend ---
echo "📦 Building frontend..."
cd "$PROJECT_ROOT/frontend"
npm ci
npm run build

echo "📋 Copying frontend build to api/public/..."
rm -rf "$PROJECT_ROOT/api/public"
cp -r "$PROJECT_ROOT/frontend/dist" "$PROJECT_ROOT/api/public"

# --- Package API ---
echo "📦 Packaging API..."
cd "$PROJECT_ROOT/api"
npm ci --production 2>/dev/null || npm install --production 2>/dev/null || npm install

DEPLOY_ZIP="/tmp/shopfast-deploy-${ENV_NAME}.zip"
rm -f "$DEPLOY_ZIP"
cd "$PROJECT_ROOT/api"
zip -r "$DEPLOY_ZIP" . -x "*.git*" > /dev/null
echo "   Archive: $DEPLOY_ZIP ($(du -h "$DEPLOY_ZIP" | cut -f1))"

# --- Deploy ---
echo "🚀 Deploying..."
DEPLOY_ARGS=(
  --name "$APP_NAME"
  --resource-group "$RESOURCE_GROUP"
  --src-path "$DEPLOY_ZIP"
  --type zip
)
[[ -n "$SLOT" ]] && DEPLOY_ARGS+=(--slot "$SLOT")

az webapp deploy "${DEPLOY_ARGS[@]}" -o none

# --- Health Check ---
echo "🏥 Running health check..."
if [[ -n "$SLOT" ]]; then
  HEALTH_URL="https://${APP_NAME}-${SLOT}.azurewebsites.net/api/health"
else
  HEALTH_URL="${APP_URL}/api/health"
fi

echo "   URL: $HEALTH_URL"
sleep 10  # Give the app a moment to start

RETRIES=5
for i in $(seq 1 $RETRIES); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" || true)
  if [[ "$HTTP_CODE" == "200" ]]; then
    echo "   ✅ Health check passed (HTTP $HTTP_CODE)"
    break
  fi
  if [[ "$i" -eq "$RETRIES" ]]; then
    echo "   ❌ Health check failed after $RETRIES attempts (last: HTTP $HTTP_CODE)" >&2
    exit 1
  fi
  echo "   ⏳ Attempt $i/$RETRIES — HTTP $HTTP_CODE, retrying in 10s..."
  sleep 10
done

# Cleanup
rm -f "$DEPLOY_ZIP"

echo ""
echo "✅ Deployment complete!"
[[ -n "$SLOT" ]] && echo "   Deployed to slot '$SLOT' — swap when ready"
