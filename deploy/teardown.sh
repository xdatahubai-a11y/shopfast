#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "⚠️  This will delete ALL ShopFast Azure resources."
echo "  - $STAGING_RG"
echo "  - $PROD_RG"
read -p "Are you sure? (yes/no) " CONFIRM
[ "$CONFIRM" = "yes" ] || { echo "Aborted."; exit 0; }

echo "Deleting staging..."
az group delete -n "$STAGING_RG" -y --no-wait 2>/dev/null || true
echo "Deleting production..."
az group delete -n "$PROD_RG" -y --no-wait 2>/dev/null || true
echo "✅ Deletion started (runs in background)"
