#!/usr/bin/env bash
set -euo pipefail

#############################################################################
# Push code update to staging or production
# Usage: ./push-code.sh --env staging|prod [--version 1.1.0] [--bad]
#############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config.sh"

ENV="" VERSION="1.0.0" USE_BAD=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --bad) USE_BAD=true; shift ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

[[ -z "$ENV" ]] && { echo "Usage: $0 --env staging|prod [--version 1.1.0] [--bad]"; exit 1; }

if [ "$ENV" = "staging" ]; then
  RG="$STAGING_RG"; APP="$STAGING_APP_NAME"
elif [ "$ENV" = "prod" ]; then
  RG="$PROD_RG"; APP="$PROD_APP_NAME"
else
  echo "Invalid env: $ENV"; exit 1
fi

echo "=== Deploying v${VERSION} to ${ENV} ==="

# Swap in the bad code if requested
cd "$REPO_DIR/api"
if [ "$USE_BAD" = true ]; then
  echo "  Using BAD version (app.bad.js → app.js)"
  cp app.bad.js app.js
fi

# Build and push
echo "  Building Docker image..."
docker build -t "$ACR_NAME.azurecr.io/shopfast:${ENV}-v${VERSION}" -t "$ACR_NAME.azurecr.io/shopfast:${ENV}-latest" .
docker push "$ACR_NAME.azurecr.io/shopfast:${ENV}-v${VERSION}"
docker push "$ACR_NAME.azurecr.io/shopfast:${ENV}-latest"

# Restart container with new image and version
echo "  Updating container..."
SQL_FQDN="${PROD_SQL_NAME}.database.windows.net"
[ "$ENV" = "staging" ] && SQL_FQDN="${STAGING_SQL_NAME}.database.windows.net"
AI_NAME="${PROD_AI_NAME}"
[ "$ENV" = "staging" ] && AI_NAME="${STAGING_AI_NAME}"
AI_CONN=$(az monitor app-insights component show -g "$RG" -a "$AI_NAME" --query 'connectionString' -o tsv 2>/dev/null)

az container create -g "$RG" -n "$APP" \
  --image "$ACR_NAME.azurecr.io/shopfast:${ENV}-v${VERSION}" \
  --registry-login-server "$ACR_NAME.azurecr.io" \
  --registry-username "$(az acr credential show -n $ACR_NAME --query username -o tsv)" \
  --registry-password "$(az acr credential show -n $ACR_NAME --query 'passwords[0].value' -o tsv)" \
  --cpu 0.5 --memory 1 \
  --ports 3000 \
  --ip-address Public \
  --environment-variables \
    SQL_SERVER="$SQL_FQDN" \
    SQL_DATABASE="shopfast" \
    SQL_USER="$SQL_ADMIN_USER" \
    PORT="3000" \
    APP_VERSION="$VERSION" \
    APPLICATIONINSIGHTS_CONNECTION_STRING="$AI_CONN" \
  --secure-environment-variables \
    SQL_PASSWORD="$SQL_ADMIN_PASS" \
  -o none

IP=$(az container show -g "$RG" -n "$APP" --query 'ipAddress.ip' -o tsv)
echo "  ✅ v${VERSION} deployed to ${ENV}: http://${IP}:3000"

# Restore good code if we swapped
if [ "$USE_BAD" = true ]; then
  cd "$REPO_DIR/api"
  git checkout app.js 2>/dev/null || true
fi
