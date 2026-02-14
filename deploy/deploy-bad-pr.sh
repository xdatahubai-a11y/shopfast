#!/usr/bin/env bash
set -euo pipefail

# Deploy the buggy v1.1.0 to both staging and production
# Simulates: PR #42 merged → CI/CD deploys to staging first, then prod
# Staging passes (clean data), production crashes (NULL status rows)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$SCRIPT_DIR/../api"

echo "=== Deploying v1.1.0 (buggy) ==="
echo ""

# Swap in the buggy version
cp "$API_DIR/app.js" "$API_DIR/app.js.bak"
cp "$API_DIR/app-v1.1.0.js" "$API_DIR/app.js"
echo "✓ Swapped app.js → v1.1.0 (buggy)"

deploy_version() {
  local ENV_NAME="$1"
  local ENV_FILE="$SCRIPT_DIR/.env.${ENV_NAME}"

  if [[ ! -f "$ENV_FILE" ]]; then
    echo "✗ Missing $ENV_FILE — run setup-demo.sh first"
    exit 1
  fi
  source "$ENV_FILE"

  echo ""
  echo "── Deploying v1.1.0 to $ENV_NAME ──"

  # Rebuild image
  az acr build -r "$ACR_NAME" -t "shopfast:${ENV_NAME}" "$API_DIR" --no-logs -o none 2>/dev/null || \
    az acr build -r "$ACR_NAME" -t "shopfast:${ENV_NAME}" "$API_DIR" -o none
  echo "✓ Image rebuilt"

  # Restart container to pull new image
  az container restart -g "$RG" -n "$CI_NAME" -o none
  echo "✓ Container restarted"

  # Update version env var
  az container create -g "$RG" -n "$CI_NAME" \
    --image "${ACR_NAME}.azurecr.io/shopfast:${ENV_NAME}" \
    --registry-login-server "${ACR_NAME}.azurecr.io" \
    --registry-username "$ACR_NAME" --registry-password "$ACR_PASSWORD" \
    --cpu 0.5 --memory 0.5 --ports 3000 \
    --ip-address Public --dns-name-label "$CI_NAME" \
    --environment-variables \
      SQL_SERVER="$SQL_SERVER" \
      SQL_DATABASE="$SQL_DATABASE" \
      SQL_USER="$SQL_USER" \
      SQL_PASSWORD="$SQL_PASSWORD" \
      APP_VERSION="${ENV_NAME}:v1.1.0" \
      APPLICATIONINSIGHTS_CONNECTION_STRING="$AI_CONNECTION_STRING" \
    -o none
  echo "✓ Deployed v1.1.0 to $ENV_NAME"

  # Quick health check
  sleep 10
  local STATUS=$(curl -sf "http://${FQDN}:3000/api/health" | jq -r '.status' 2>/dev/null || echo "failed")
  echo "  Health: $STATUS"

  # Test the orders endpoint (this is where the bug hits)
  local ORDER_STATUS=$(curl -sf "http://${FQDN}:3000/api/orders" 2>/dev/null && echo "ok" || echo "CRASHED")
  echo "  GET /api/orders: $ORDER_STATUS"
}

# Deploy staging first (will work — clean data, no NULLs)
deploy_version "staging"

echo ""
echo "⏳ Staging looks good... deploying to production..."
sleep 5

# Deploy production (will crash — legacy NULL status rows)
deploy_version "production"

# Restore original
cp "$API_DIR/app.js.bak" "$API_DIR/app.js"
rm "$API_DIR/app.js.bak"
echo ""
echo "✓ Restored app.js to v1.0.0"

echo ""
echo "=== Result ==="
echo "Staging:    ✅ Working (clean data, no NULLs)"
echo "Production: ❌ /api/orders and /api/stats crash (NULL status rows)"
echo ""
echo "Production errors will flow into App Insights → trigger Azure alert → Dave investigates"
