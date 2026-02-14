#!/usr/bin/env bash
set -euo pipefail

#############################################################################
# ShopFast — Full Infrastructure Setup
# Creates staging + production environments with SQL, App Insights, Container App
#
# Usage: ./setup.sh [--staging-only] [--prod-only] [--skip-db-seed]
#############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config.sh"

STAGING_ONLY=false
PROD_ONLY=false
SKIP_SEED=false
for arg in "$@"; do
  case "$arg" in
    --staging-only) STAGING_ONLY=true ;;
    --prod-only) PROD_ONLY=true ;;
    --skip-db-seed) SKIP_SEED=true ;;
  esac
done

log() { echo ""; echo "=== $(date +%H:%M:%S) $*"; }

#############################################################################
deploy_environment() {
  local ENV_NAME=$1  # "staging" or "prod"
  local SUB=$2
  local RG=$3
  local LOCATION=$4
  local SQL_NAME=$5
  local DB_NAME=$6
  local APP_NAME=$7
  local AI_NAME=$8
  local LA_NAME=$9
  local SEED_FILE=${10}

  log "[$ENV_NAME] Setting subscription..."
  az account set -s "$SUB" 2>/dev/null || true

  log "[$ENV_NAME] Creating resource group: $RG"
  az group create -n "$RG" -l "$LOCATION" -o none

  log "[$ENV_NAME] Creating Log Analytics workspace..."
  az monitor log-analytics workspace create -g "$RG" -n "$LA_NAME" -l "$LOCATION" --retention-time 30 -o none 2>/dev/null || true
  LA_ID=$(az monitor log-analytics workspace show -g "$RG" -n "$LA_NAME" --query 'id' -o tsv)

  log "[$ENV_NAME] Creating App Insights..."
  az monitor app-insights component create -g "$RG" -a "$AI_NAME" -l "$LOCATION" --workspace "$LA_ID" --kind web -o none 2>/dev/null || true
  AI_CONN=$(az monitor app-insights component show -g "$RG" -a "$AI_NAME" --query 'connectionString' -o tsv)

  log "[$ENV_NAME] Creating SQL Server..."
  az sql server create -g "$RG" -n "$SQL_NAME" -l "$LOCATION" \
    --admin-user "$SQL_ADMIN_USER" --admin-password "$SQL_ADMIN_PASS" -o none 2>/dev/null || true
  # Allow Azure services
  az sql server firewall-rule create -g "$RG" -s "$SQL_NAME" -n "AllowAzure" \
    --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 -o none 2>/dev/null || true
  # Allow local IP for seeding
  MY_IP=$(curl -s ifconfig.me)
  az sql server firewall-rule create -g "$RG" -s "$SQL_NAME" -n "LocalDev" \
    --start-ip-address "$MY_IP" --end-ip-address "$MY_IP" -o none 2>/dev/null || true

  log "[$ENV_NAME] Creating SQL Database (Basic tier)..."
  az sql db create -g "$RG" -s "$SQL_NAME" -n "$DB_NAME" \
    --edition Basic --capacity 5 --max-size 2GB -o none 2>/dev/null || true

  log "[$ENV_NAME] Applying schema..."
  SQL_FQDN="${SQL_NAME}.database.windows.net"
  sqlcmd -S "$SQL_FQDN" -U "$SQL_ADMIN_USER" -P "$SQL_ADMIN_PASS" -d "$DB_NAME" \
    -i "$REPO_DIR/db/schema.sql" -b 2>/dev/null || echo "  Schema may already exist"

  if [ "$SKIP_SEED" = false ]; then
    log "[$ENV_NAME] Seeding data from $SEED_FILE..."
    sqlcmd -S "$SQL_FQDN" -U "$SQL_ADMIN_USER" -P "$SQL_ADMIN_PASS" -d "$DB_NAME" \
      -i "$REPO_DIR/db/$SEED_FILE" -b 2>/dev/null || echo "  Seed data may already exist"
  fi

  log "[$ENV_NAME] Building and pushing Docker image..."
  if [ "$ENV_NAME" = "staging" ]; then
    # Create ACR in staging RG (shared)
    az acr create -g "$RG" -n "$ACR_NAME" --sku Basic -o none 2>/dev/null || true
    az acr login -n "$ACR_NAME" 2>/dev/null || true
  fi
  cd "$REPO_DIR/api"
  docker build -t "$ACR_NAME.azurecr.io/shopfast:${ENV_NAME}-latest" .
  docker push "$ACR_NAME.azurecr.io/shopfast:${ENV_NAME}-latest"

  log "[$ENV_NAME] Creating Container Instance..."
  az container create -g "$RG" -n "$APP_NAME" \
    --image "$ACR_NAME.azurecr.io/shopfast:${ENV_NAME}-latest" \
    --registry-login-server "$ACR_NAME.azurecr.io" \
    --registry-username "$(az acr credential show -n $ACR_NAME --query username -o tsv)" \
    --registry-password "$(az acr credential show -n $ACR_NAME --query 'passwords[0].value' -o tsv)" \
    --cpu 0.5 --memory 1 \
    --ports 3000 \
    --ip-address Public \
    --environment-variables \
      SQL_SERVER="$SQL_FQDN" \
      SQL_DATABASE="$DB_NAME" \
      SQL_USER="$SQL_ADMIN_USER" \
      PORT="3000" \
      APP_VERSION="1.0.0" \
      APPLICATIONINSIGHTS_CONNECTION_STRING="$AI_CONN" \
    --secure-environment-variables \
      SQL_PASSWORD="$SQL_ADMIN_PASS" \
    -o none 2>/dev/null || true

  local IP=$(az container show -g "$RG" -n "$APP_NAME" --query 'ipAddress.ip' -o tsv)
  log "[$ENV_NAME] ✅ Deployed at http://$IP:3000"
  echo "$IP" > "/tmp/shopfast-${ENV_NAME}-ip.txt"
}

#############################################################################
# Main
#############################################################################

log "🏗️  ShopFast Infrastructure Setup"
echo "  Mode: $DEPLOY_MODE"
echo "  Staging: $STAGING_RG ($STAGING_LOCATION)"
echo "  Prod:    $PROD_RG ($PROD_LOCATION)"

# Install sqlcmd if missing
if ! command -v sqlcmd &>/dev/null; then
  log "Installing sqlcmd..."
  curl -s https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
  sudo add-apt-repository "$(curl -s https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list)" 2>/dev/null
  sudo ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev 2>/dev/null
  export PATH="$PATH:/opt/mssql-tools18/bin"
fi

if [ "$PROD_ONLY" = false ]; then
  deploy_environment "staging" "$STAGING_SUB" "$STAGING_RG" "$STAGING_LOCATION" \
    "$STAGING_SQL_NAME" "$STAGING_DB_NAME" "$STAGING_APP_NAME" \
    "$STAGING_AI_NAME" "$STAGING_LA_NAME" "seed-staging.sql"
fi

if [ "$STAGING_ONLY" = false ]; then
  deploy_environment "prod" "$PROD_SUB" "$PROD_RG" "$PROD_LOCATION" \
    "$PROD_SQL_NAME" "$PROD_DB_NAME" "$PROD_APP_NAME" \
    "$PROD_AI_NAME" "$PROD_LA_NAME" "seed-production.sql"
fi

#############################################################################
log "📊 Creating alerts on production..."
PROD_AI_ID=$(az monitor app-insights component show -g "$PROD_RG" -a "$PROD_AI_NAME" --query 'id' -o tsv 2>/dev/null)
PROD_LA_ID=$(az monitor log-analytics workspace show -g "$PROD_RG" -n "$PROD_LA_NAME" --query 'id' -o tsv 2>/dev/null)

# Action group (with Dave webhook if configured)
AG_ARGS=(-g "$PROD_RG" -n "shopfast-alerts-ag" --short-name "SFAlerts")
if [ -n "$DAVE_WEBHOOK_URL" ]; then
  AG_ARGS+=(--action webhook DaveHooks "$DAVE_WEBHOOK_URL")
fi
az monitor action-group create "${AG_ARGS[@]}" -o none 2>/dev/null || true
AG_ID=$(az monitor action-group show -g "$PROD_RG" -n "shopfast-alerts-ag" --query 'id' -o tsv)

# Failed requests alert
az monitor scheduled-query create -g "$PROD_RG" -n "shopfast-failed-requests" \
  --scopes "$PROD_LA_ID" \
  --condition "count 'AppRequests | where Success == false | summarize cnt=count() | where cnt > 5' > 0" \
  --evaluation-frequency 5m --window-size 10m --severity 2 \
  --action-groups "$AG_ID" \
  -o none 2>/dev/null || true

# Exception spike alert
az monitor scheduled-query create -g "$PROD_RG" -n "shopfast-exceptions" \
  --scopes "$PROD_LA_ID" \
  --condition "count 'AppExceptions | summarize cnt=count() | where cnt > 5' > 0" \
  --evaluation-frequency 5m --window-size 10m --severity 1 \
  --action-groups "$AG_ID" \
  -o none 2>/dev/null || true

# Response time alert
az monitor metrics alert create -g "$PROD_RG" -n "shopfast-response-time" \
  --scopes "$PROD_AI_ID" \
  --condition "avg requests/duration > 2000" \
  --window-size 5m --evaluation-frequency 1m \
  --severity 3 --action "$AG_ID" \
  -o none 2>/dev/null || true

log "✅ Alerts created on production"

#############################################################################
STAGING_IP=$(cat /tmp/shopfast-staging-ip.txt 2>/dev/null || echo "unknown")
PROD_IP=$(cat /tmp/shopfast-prod-ip.txt 2>/dev/null || echo "unknown")

log "🚀 Setup Complete!"
echo ""
echo "  Staging:    http://${STAGING_IP}:3000"
echo "  Production: http://${PROD_IP}:3000"
echo "  GitHub:     https://github.com/$GITHUB_REPO"
echo ""
echo "  SQL Admin:  $SQL_ADMIN_USER / $SQL_ADMIN_PASS"
echo "  ACR:        $ACR_NAME.azurecr.io"
echo ""
echo "  Next: Run the demo with: cd demo && ./run-demo.sh"
