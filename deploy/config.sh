#!/usr/bin/env bash
# ShopFast Deployment Configuration
# Edit these values for your environment

# Mode: "subscriptions" (two subs) or "resourcegroups" (two RGs in one sub)
export DEPLOY_MODE="resourcegroups"

# Staging
export STAGING_SUB="${STAGING_SUB:-bcc586a3-24e2-4098-94b2-0556003c7ed0}"
export STAGING_RG="shopfast-staging-rg"
export STAGING_LOCATION="eastus2"
export STAGING_SQL_NAME="shopfast-staging-sql"
export STAGING_DB_NAME="shopfast"
export STAGING_APP_NAME="shopfast-staging"
export STAGING_AI_NAME="shopfast-staging-ai"
export STAGING_LA_NAME="shopfast-staging-logs"

# Production
export PROD_SUB="${PROD_SUB:-$STAGING_SUB}"  # Same sub if using RG mode
export PROD_RG="shopfast-prod-rg"
export PROD_LOCATION="eastus2"
export PROD_SQL_NAME="shopfast-prod-sql"
export PROD_DB_NAME="shopfast"
export PROD_APP_NAME="shopfast-prod"
export PROD_AI_NAME="shopfast-prod-ai"
export PROD_LA_NAME="shopfast-prod-logs"

# Shared
export ACR_NAME="shopfastacr$(openssl rand -hex 3)"
export ACR_RG="$STAGING_RG"  # ACR goes in staging RG
export SQL_ADMIN_USER="sfadmin"
export SQL_ADMIN_PASS="ShopFast2026!$(openssl rand -hex 4)"

# Dave
export DAVE_WEBHOOK_URL="${DAVE_WEBHOOK_URL:-}"
export DAVE_IDENTITY_CLIENT_ID="${DAVE_IDENTITY_CLIENT_ID:-}"

# GitHub
export GITHUB_REPO="xdatahubai-a11y/shopfast"
