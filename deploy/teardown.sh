#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# teardown.sh — Delete all ShopFast Azure resources
###############################################################################

echo "=== ShopFast Teardown ==="
echo "⚠️  Deleting both resource groups (async)..."

az group delete --name shopfast-staging-rg --yes --no-wait 2>/dev/null && \
  echo "  ✅ shopfast-staging-rg deletion started" || \
  echo "  ⚠️  shopfast-staging-rg not found or already deleted"

az group delete --name shopfast-prod-rg --yes --no-wait 2>/dev/null && \
  echo "  ✅ shopfast-prod-rg deletion started" || \
  echo "  ⚠️  shopfast-prod-rg not found or already deleted"

# Clean up GitHub branch if it exists
echo "Cleaning up GitHub branch..."
git push origin --delete feature/status-badges 2>/dev/null && \
  echo "  ✅ Deleted feature/status-badges branch" || \
  echo "  ⚠️  Branch already deleted or not found"

echo ""
echo "✅ Teardown initiated. Resource groups deleting in background."
echo "   Run 'az group list -o table' to check progress."
