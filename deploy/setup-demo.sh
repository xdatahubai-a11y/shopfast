#!/usr/bin/env bash
set -euo pipefail

# ShopFast Demo — Infrastructure Setup
# Creates two resource groups (staging + production) with identical architecture:
#   Azure SQL, App Insights, Log Analytics, Container Instance
# Staging gets clean data, production gets legacy data with NULLs

LOCATION="${LOCATION:-eastus2}"
RG_STAGING="shopfast-staging-rg"
RG_PROD="shopfast-prod-rg"
SQL_ADMIN="shopfastadmin"
SQL_PASS="${SQL_PASSWORD:-$(openssl rand -base64 16 | tr -d '=/+')Aa1!}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$SCRIPT_DIR/../api"
DB_DIR="$SCRIPT_DIR/../db"

echo "=== ShopFast Demo Infrastructure Setup ==="
echo "Location: $LOCATION"
echo "SQL Password: $SQL_PASS"
echo ""

deploy_environment() {
  local ENV_NAME="$1"    # staging | production
  local RG="$2"
  local SEED_FILE="$3"
  local PREFIX="sf${ENV_NAME:0:4}"  # sfstag | sfprod

  echo "──────────────────────────────────────"
  echo "Deploying: $ENV_NAME ($RG)"
  echo "──────────────────────────────────────"

  # Resource Group
  az group create -n "$RG" -l "$LOCATION" -o none
  echo "✓ Resource group: $RG"

  # Log Analytics
  local LAW_NAME="${PREFIX}-logs-$(openssl rand -hex 4)"
  az monitor log-analytics workspace create -g "$RG" -n "$LAW_NAME" --retention-time 30 -o none
  local LAW_ID=$(az monitor log-analytics workspace show -g "$RG" -n "$LAW_NAME" --query id -o tsv)
  echo "✓ Log Analytics: $LAW_NAME"

  # App Insights
  local AI_NAME="${PREFIX}-ai-$(openssl rand -hex 4)"
  az monitor app-insights component create -g "$RG" -a "$AI_NAME" -l "$LOCATION" \
    --workspace "$LAW_ID" --kind web --application-type web -o none
  local AI_CONN=$(az monitor app-insights component show -g "$RG" -a "$AI_NAME" \
    --query connectionString -o tsv)
  echo "✓ App Insights: $AI_NAME"

  # Azure SQL Server + Database
  local SQL_SERVER="${PREFIX}-sql-$(openssl rand -hex 4)"
  az sql server create -g "$RG" -n "$SQL_SERVER" \
    --admin-user "$SQL_ADMIN" --admin-password "$SQL_PASS" -l "$LOCATION" -o none
  # Allow Azure services
  az sql server firewall-rule create -g "$RG" -s "$SQL_SERVER" \
    -n AllowAzure --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 -o none
  # Allow current IP for schema setup
  local MY_IP=$(curl -s ifconfig.me)
  az sql server firewall-rule create -g "$RG" -s "$SQL_SERVER" \
    -n SetupIP --start-ip-address "$MY_IP" --end-ip-address "$MY_IP" -o none
  az sql db create -g "$RG" -s "$SQL_SERVER" -n shopfast \
    --service-objective Basic --max-size 2GB -o none
  echo "✓ SQL: $SQL_SERVER.database.windows.net/shopfast"

  # Apply schema + seed data
  local SQL_FQDN="${SQL_SERVER}.database.windows.net"
  echo "Applying schema..."
  sqlcmd -S "$SQL_FQDN" -d shopfast -U "$SQL_ADMIN" -P "$SQL_PASS" -i "$DB_DIR/schema.sql" -C 2>/dev/null || \
    echo "  (schema may already exist)"
  echo "Applying seed data ($SEED_FILE)..."
  sqlcmd -S "$SQL_FQDN" -d shopfast -U "$SQL_ADMIN" -P "$SQL_PASS" -i "$SEED_FILE" -C 2>/dev/null || \
    echo "  (seed may already exist)"
  echo "✓ Database seeded"

  # Build & deploy Container Instance (using ACR build)
  local ACR_NAME="${PREFIX}acr$(openssl rand -hex 3)"
  az acr create -g "$RG" -n "$ACR_NAME" --sku Basic --admin-enabled true -o none
  local ACR_PASS=$(az acr credential show -n "$ACR_NAME" --query "passwords[0].value" -o tsv)
  echo "✓ ACR: $ACR_NAME"

  echo "Building image via ACR..."
  az acr build -r "$ACR_NAME" -t "shopfast:${ENV_NAME}" "$API_DIR" --no-logs -o none 2>/dev/null || \
    az acr build -r "$ACR_NAME" -t "shopfast:${ENV_NAME}" "$API_DIR" -o none
  echo "✓ Image built"

  # Container Instance
  local CI_NAME="shopfast-${ENV_NAME}"
  az container create -g "$RG" -n "$CI_NAME" \
    --image "${ACR_NAME}.azurecr.io/shopfast:${ENV_NAME}" \
    --registry-login-server "${ACR_NAME}.azurecr.io" \
    --registry-username "$ACR_NAME" --registry-password "$ACR_PASS" \
    --cpu 0.5 --memory 0.5 --ports 3000 \
    --ip-address Public --dns-name-label "$CI_NAME" \
    --environment-variables \
      SQL_SERVER="$SQL_FQDN" \
      SQL_DATABASE=shopfast \
      SQL_USER="$SQL_ADMIN" \
      SQL_PASSWORD="$SQL_PASS" \
      APP_VERSION="${ENV_NAME}:v1.0.0" \
      APPLICATIONINSIGHTS_CONNECTION_STRING="$AI_CONN" \
    -o none
  local FQDN=$(az container show -g "$RG" -n "$CI_NAME" --query ipAddress.fqdn -o tsv)
  echo "✓ Container: http://${FQDN}:3000"

  # Save env info
  cat > "$SCRIPT_DIR/.env.${ENV_NAME}" <<EOF
RG=$RG
SQL_SERVER=$SQL_FQDN
SQL_DATABASE=shopfast
SQL_USER=$SQL_ADMIN
SQL_PASSWORD=$SQL_PASS
ACR_NAME=$ACR_NAME
ACR_PASSWORD=$ACR_PASS
AI_NAME=$AI_NAME
AI_CONNECTION_STRING=$AI_CONN
LAW_NAME=$LAW_NAME
CI_NAME=$CI_NAME
FQDN=$FQDN
EOF
  echo "✓ Saved: deploy/.env.${ENV_NAME}"
  echo ""
}

# Deploy both environments
deploy_environment "staging" "$RG_STAGING" "$DB_DIR/seed-staging.sql"
deploy_environment "production" "$RG_PROD" "$DB_DIR/seed-production.sql"

echo "=== Setup Complete ==="
echo ""
echo "Staging:    http://$(grep FQDN $SCRIPT_DIR/.env.staging | cut -d= -f2):3000"
echo "Production: http://$(grep FQDN $SCRIPT_DIR/.env.production | cut -d= -f2):3000"
echo ""
echo "Both running v1.0.0 (safe). Use deploy-bad-pr.sh to introduce the bug."
