#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# capture-screenshots.sh — Log URLs for screenshot capture at each demo step
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/.env.staging"
STAGING_URL="$APP_URL"
source "$SCRIPT_DIR/.env.production"
PROD_URL="$APP_URL"

SCREENSHOTS_DIR="$SCRIPT_DIR/../screenshots"
mkdir -p "$SCREENSHOTS_DIR"

capture_step() {
  local STEP="$1"
  local DESC="$2"
  shift 2
  local URLS=("$@")

  echo ""
  echo "📸 Step: $STEP — $DESC"
  for URL in "${URLS[@]}"; do
    local FILENAME="${STEP}-$(echo "$URL" | sed 's|https\?://||;s|[/:]|_|g').html"
    echo "   Capturing: $URL"
    curl -s -o "$SCREENSHOTS_DIR/$FILENAME" "$URL" 2>/dev/null && \
      echo "   → Saved: screenshots/$FILENAME" || \
      echo "   → Failed (will capture via browser tools)"
    echo "   🔗 $URL"
  done
}

echo "=== ShopFast Screenshot Capture Helper ==="
echo "Screenshots dir: $SCREENSHOTS_DIR"

# Pre-deploy: both healthy
capture_step "01-pre-deploy" "Both environments healthy" \
  "$STAGING_URL" \
  "$STAGING_URL/api/health" \
  "$PROD_URL" \
  "$PROD_URL/api/health" \
  "$PROD_URL/api/orders"

# GitHub PR
echo ""
echo "📸 Step: 02-github-pr — Capture manually from GitHub"
echo "   🔗 Open GitHub repo → Pull Requests → PR #42"

# Post-deploy: staging OK, production broken
capture_step "03-post-deploy" "After buggy deploy" \
  "$STAGING_URL/api/orders" \
  "$PROD_URL/api/orders" \
  "$PROD_URL/api/stats"

# Azure portal
echo ""
echo "📸 Step: 04-azure-alerts — Capture from Azure Portal"
echo "   🔗 https://portal.azure.com → App Insights → Failures"
echo "   🔗 https://portal.azure.com → Monitor → Alerts"

# GitHub Actions
echo ""
echo "📸 Step: 05-github-actions — Capture workflow run"
echo "   🔗 Open GitHub repo → Actions → Latest run"

echo ""
echo "✅ HTML captures saved to: $SCREENSHOTS_DIR/"
echo "   Use browser tools for proper screenshots of Azure Portal & GitHub"
