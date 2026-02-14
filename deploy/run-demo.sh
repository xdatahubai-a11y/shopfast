#!/usr/bin/env bash
set -euo pipefail

# ShopFast Demo — Full Timeline Orchestrator
# Runs the complete demo sequence with narration

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "╔══════════════════════════════════════════╗"
echo "║     ShopFast E-Commerce Demo             ║"
echo "║     SRE Agent Incident Response          ║"
echo "╚══════════════════════════════════════════╝"
echo ""

step() {
  local n="$1"; shift
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Step $n: $*"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

STAGING_URL="http://$(grep FQDN "$SCRIPT_DIR/.env.staging" | cut -d= -f2):3000"
PROD_URL="http://$(grep FQDN "$SCRIPT_DIR/.env.production" | cut -d= -f2):3000"

# ── Step 1: Show current state ──
step 1 "Both environments healthy on v1.0.0"
echo "Staging:    $STAGING_URL"
echo "Production: $PROD_URL"
echo ""
echo "Staging health:"
curl -sf "$STAGING_URL/api/health" | jq .
echo ""
echo "Production health:"
curl -sf "$PROD_URL/api/health" | jq .
echo ""
echo "Production orders (v1.0.0 handles NULLs gracefully):"
curl -sf "$PROD_URL/api/orders" | jq '.count, (.orders[] | {id, status})' 2>/dev/null | head -30
echo ""
read -p "Press Enter to continue..."

# ── Step 2: Create the bad PR ──
step 2 "Developer creates PR #42: 'Add status badge system'"
echo "A developer wants to add colored status badges to the dashboard."
echo "They test against the staging database — all 5 statuses display perfectly."
echo "They don't know production has legacy orders with NULL status from a 2023 migration."
echo ""
read -p "Press Enter to create the PR on GitHub..."
bash "$SCRIPT_DIR/create-bad-pr.sh"
echo ""
read -p "Press Enter to continue..."

# ── Step 3: Deploy to staging ──
step 3 "CI/CD deploys v1.1.0 to staging"
echo "PR merges → pipeline deploys to staging first..."
echo ""
# Only deploy staging part
source "$SCRIPT_DIR/.env.staging"
cp "$SCRIPT_DIR/../api/app-v1.1.0.js" "$SCRIPT_DIR/../api/app.js"
az acr build -r "$ACR_NAME" -t "shopfast:staging" "$SCRIPT_DIR/../api" --no-logs -o none 2>/dev/null || \
  az acr build -r "$ACR_NAME" -t "shopfast:staging" "$SCRIPT_DIR/../api" -o none
az container restart -g "$RG" -n "$CI_NAME" -o none
cp "$SCRIPT_DIR/../api/app.js.bak" "$SCRIPT_DIR/../api/app.js" 2>/dev/null || \
  git -C "$SCRIPT_DIR/.." checkout api/app.js 2>/dev/null || true
sleep 15
echo ""
echo "Staging v1.1.0 — testing endpoints:"
curl -sf "$STAGING_URL/api/health" | jq .version
echo "Orders:"
curl -sf "$STAGING_URL/api/orders" | jq '.count'
echo "Stats:"
curl -sf "$STAGING_URL/api/stats" | jq '.byStatus'
echo ""
echo "✅ Staging passes! All endpoints working. Status badges look great."
echo ""
read -p "Press Enter to deploy to production..."

# ── Step 4: Deploy to production ──
step 4 "CI/CD deploys v1.1.0 to production — 💥 BOOM"
echo "Pipeline promotes to production..."
echo ""
source "$SCRIPT_DIR/.env.production"
cp "$SCRIPT_DIR/../api/app-v1.1.0.js" "$SCRIPT_DIR/../api/app.js"
az acr build -r "$ACR_NAME" -t "shopfast:production" "$SCRIPT_DIR/../api" --no-logs -o none 2>/dev/null || \
  az acr build -r "$ACR_NAME" -t "shopfast:production" "$SCRIPT_DIR/../api" -o none
az container restart -g "$RG" -n "$CI_NAME" -o none
cp "$SCRIPT_DIR/../api/app.js.bak" "$SCRIPT_DIR/../api/app.js" 2>/dev/null || \
  git -C "$SCRIPT_DIR/.." checkout api/app.js 2>/dev/null || true
sleep 15
echo ""
echo "Production v1.1.0 — testing:"
curl -sf "$PROD_URL/api/health" | jq .version
echo "Orders:"
curl -sf "$PROD_URL/api/orders" 2>/dev/null && echo "OK" || echo "❌ 500 ERROR — CRASHED!"
echo "Stats:"
curl -sf "$PROD_URL/api/stats" 2>/dev/null && echo "OK" || echo "❌ 500 ERROR — CRASHED!"
echo ""
echo "💥 Production is DOWN. /api/orders and /api/stats return 500."
echo "   Root cause: formatStatus() calls .toLowerCase() on NULL status"
echo "   Legacy orders from 2023 migration have NULL status fields"
echo ""
read -p "Press Enter to generate traffic (triggers alert → Dave)..."

# ── Step 5: Generate traffic to trigger alerts ──
step 5 "Users hitting production — errors pile up in App Insights"
echo "Simulating user traffic..."
for i in $(seq 1 50); do
  curl -sf "$PROD_URL/api/orders" >/dev/null 2>&1 &
  curl -sf "$PROD_URL/api/stats" >/dev/null 2>&1 &
  [[ $((i % 10)) -eq 0 ]] && echo "  $i requests sent..."
done
wait
echo ""
echo "✓ 100 requests sent. ~50% hitting crash endpoints."
echo "  App Insights is collecting 500s and exceptions."
echo "  Azure Monitor alert will fire within 1-5 minutes."
echo ""

# ── Step 6: Wait for Dave ──
step 6 "Waiting for Dave..."
echo "Azure Monitor evaluates every 1 minute."
echo "When >3 failures in 5min → alert fires → webhook → Dave wakes up."
echo ""
echo "Watch Dave's Telegram for:"
echo "  1. 🔔 Alert received notification"
echo "  2. 🔍 Investigation starts (queries App Insights, identifies NULL crash)"
echo "  3. 🔗 Code correlation (finds PR #42, traces formatStatus())"
echo "  4. 🔧 Fix PR created (adds null check back to formatStatus)"
echo "  5. 📊 Incident report posted"
echo ""
echo "Demo complete! Dave takes it from here."
