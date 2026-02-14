#!/usr/bin/env bash
set -euo pipefail

echo "=== Tearing down ShopFast demo ==="
az group delete -n shopfast-staging-rg --yes --no-wait 2>/dev/null && echo "✓ Deleting shopfast-staging-rg" || echo "  (not found)"
az group delete -n shopfast-prod-rg --yes --no-wait 2>/dev/null && echo "✓ Deleting shopfast-prod-rg" || echo "  (not found)"
echo "Done. Deletion runs in background (~5 min)."
