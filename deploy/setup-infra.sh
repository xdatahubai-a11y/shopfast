#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-infra.sh — Provision Azure infrastructure for ShopFast (staging + prod)
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOCATION="${AZURE_LOCATION:-eastus}"
SUFFIX="${RESOURCE_SUFFIX:-$(head -c 4 /dev/urandom | xxd -p)}"
SQL_ADMIN="shopfastadmin"
SQL_PASSWORD="${SQL_PASSWORD:-$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9!@#' | head -c 20)}"

echo "=== ShopFast Infrastructure Setup ==="
echo "Location: $LOCATION"
echo "Suffix:   $SUFFIX"
echo ""

setup_environment() {
  local ENV_NAME="$1"    # staging | production
  local RG="$2"          # resource group name
  local ENV_FILE="$SCRIPT_DIR/.env.${ENV_NAME}"

  echo ""
  echo "========================================"
  echo "  Setting up: $ENV_NAME ($RG)"
  echo "========================================"

  # --- Resource Group ---
  echo "Creating resource group..."
  az group create --name "$RG" --location "$LOCATION" -o none

  # --- Log Analytics Workspace ---
  local LAW_NAME="shopfast-${ENV_NAME}-law-${SUFFIX}"
  echo "Creating Log Analytics Workspace: $LAW_NAME"
  az monitor log-analytics workspace create \
    --resource-group "$RG" \
    --workspace-name "$LAW_NAME" \
    --location "$LOCATION" \
    --retention-time 30 \
    -o none

  local LAW_ID
  LAW_ID=$(az monitor log-analytics workspace show \
    --resource-group "$RG" \
    --workspace-name "$LAW_NAME" \
    --query id -o tsv)

  # --- App Insights ---
  local AI_NAME="shopfast-${ENV_NAME}-ai-${SUFFIX}"
  echo "Creating Application Insights: $AI_NAME"
  az monitor app-insights component create \
    --app "$AI_NAME" \
    --location "$LOCATION" \
    --resource-group "$RG" \
    --workspace "$LAW_ID" \
    --kind web \
    --application-type web \
    -o none

  local AI_CONN_STR
  AI_CONN_STR=$(az monitor app-insights component show \
    --app "$AI_NAME" \
    --resource-group "$RG" \
    --query connectionString -o tsv)

  # --- Azure SQL Server ---
  local SQL_SERVER_NAME="shopfast-${ENV_NAME}-sql-${SUFFIX}"
  local SQL_DB_NAME="shopfastdb"
  local SQL_FQDN="${SQL_SERVER_NAME}.database.windows.net"

  echo "Creating SQL Server: $SQL_SERVER_NAME"
  az sql server create \
    --name "$SQL_SERVER_NAME" \
    --resource-group "$RG" \
    --location "$LOCATION" \
    --admin-user "$SQL_ADMIN" \
    --admin-password "$SQL_PASSWORD" \
    -o none

  # Firewall: allow Azure services
  echo "Configuring firewall rules..."
  az sql server firewall-rule create \
    --resource-group "$RG" \
    --server "$SQL_SERVER_NAME" \
    --name "AllowAzureServices" \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0 \
    -o none

  # Firewall: allow current IP
  local MY_IP
  MY_IP=$(curl -s https://ifconfig.me)
  az sql server firewall-rule create \
    --resource-group "$RG" \
    --server "$SQL_SERVER_NAME" \
    --name "AllowCurrentIP" \
    --start-ip-address "$MY_IP" \
    --end-ip-address "$MY_IP" \
    -o none

  # Database (Basic tier, 2GB)
  echo "Creating SQL Database: $SQL_DB_NAME (Basic tier)"
  az sql db create \
    --resource-group "$RG" \
    --server "$SQL_SERVER_NAME" \
    --name "$SQL_DB_NAME" \
    --edition Basic \
    --capacity 5 \
    --max-size 2GB \
    -o none

  # Install mssql if needed (for SQL runner)
  if [[ ! -d "$PROJECT_ROOT/db/node_modules/mssql" ]]; then
    echo "Installing mssql driver..."
    (cd "$PROJECT_ROOT/db" && npm init -y --silent && npm install --silent mssql) >/dev/null 2>&1
  fi

  # Apply schema
  echo "Applying schema..."
  node "$PROJECT_ROOT/db/run-sql.js" "$SQL_FQDN" "$SQL_DB_NAME" "$SQL_ADMIN" "$SQL_PASSWORD" \
    "$PROJECT_ROOT/db/schema.sql"

  # Apply seed data
  local SEED_FILE
  if [[ "$ENV_NAME" == "staging" ]]; then
    SEED_FILE="$PROJECT_ROOT/db/seed-staging.sql"
  else
    SEED_FILE="$PROJECT_ROOT/db/seed-production.sql"
  fi
  echo "Applying seed data from $(basename "$SEED_FILE")..."
  node "$PROJECT_ROOT/db/run-sql.js" "$SQL_FQDN" "$SQL_DB_NAME" "$SQL_ADMIN" "$SQL_PASSWORD" \
    "$SEED_FILE"

  # --- App Service Plan ---
  local PLAN_NAME="shopfast-${ENV_NAME}-plan-${SUFFIX}"
  echo "Creating App Service Plan: $PLAN_NAME (B1 Linux)"
  az appservice plan create \
    --name "$PLAN_NAME" \
    --resource-group "$RG" \
    --sku B1 \
    --is-linux \
    -o none

  # --- App Service ---
  local APP_NAME="shopfast-${ENV_NAME}-${SUFFIX}"
  echo "Creating App Service: $APP_NAME (Node 20 LTS)"
  az webapp create \
    --name "$APP_NAME" \
    --resource-group "$RG" \
    --plan "$PLAN_NAME" \
    --runtime "NODE:20-lts" \
    -o none

  # App Settings
  echo "Configuring app settings..."
  az webapp config appsettings set \
    --name "$APP_NAME" \
    --resource-group "$RG" \
    --settings \
      SQL_SERVER="$SQL_FQDN" \
      SQL_DATABASE="$SQL_DB_NAME" \
      SQL_USER="$SQL_ADMIN" \
      SQL_PASSWORD="$SQL_PASSWORD" \
      APP_VERSION="1.0.0" \
      APPLICATIONINSIGHTS_CONNECTION_STRING="$AI_CONN_STR" \
    -o none

  # Production only: deployment slot
  if [[ "$ENV_NAME" == "production" ]]; then
    echo "Creating deployment slot 'staging' on production app..."
    az webapp deployment slot create \
      --name "$APP_NAME" \
      --resource-group "$RG" \
      --slot staging \
      -o none

    # Same settings on the slot (shares production DB)
    az webapp config appsettings set \
      --name "$APP_NAME" \
      --resource-group "$RG" \
      --slot staging \
      --settings \
        SQL_SERVER="$SQL_FQDN" \
        SQL_DATABASE="$SQL_DB_NAME" \
        SQL_USER="$SQL_ADMIN" \
        SQL_PASSWORD="$SQL_PASSWORD" \
        APP_VERSION="1.0.0" \
        APPLICATIONINSIGHTS_CONNECTION_STRING="$AI_CONN_STR" \
      -o none
  fi

  # --- Save .env file ---
  cat > "$ENV_FILE" <<EOF
# ShopFast ${ENV_NAME} environment — generated $(date -u +%Y-%m-%dT%H:%M:%SZ)
RESOURCE_GROUP=${RG}
LOCATION=${LOCATION}
SUFFIX=${SUFFIX}
SQL_SERVER_NAME=${SQL_SERVER_NAME}
SQL_FQDN=${SQL_FQDN}
SQL_DATABASE=${SQL_DB_NAME}
SQL_ADMIN=${SQL_ADMIN}
SQL_PASSWORD=${SQL_PASSWORD}
APP_SERVICE_PLAN=${PLAN_NAME}
APP_NAME=${APP_NAME}
APP_INSIGHTS_NAME=${AI_NAME}
APP_INSIGHTS_CONN_STR=${AI_CONN_STR}
LOG_ANALYTICS_WORKSPACE=${LAW_NAME}
APP_URL=https://${APP_NAME}.azurewebsites.net
EOF

  echo "✅ $ENV_NAME environment ready → $ENV_FILE"
}

# ---- Main ----
setup_environment "staging"    "shopfast-staging-rg"
setup_environment "production" "shopfast-prod-rg"

echo ""
echo "========================================"
echo "  ✅ All infrastructure provisioned!"
echo "========================================"
echo "  Staging:    https://shopfast-staging-${SUFFIX}.azurewebsites.net"
echo "  Production: https://shopfast-production-${SUFFIX}.azurewebsites.net"
echo "  SQL Password saved to .env files"
echo "========================================"
