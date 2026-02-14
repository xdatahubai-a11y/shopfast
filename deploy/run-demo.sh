#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# run-demo.sh — Full automated demo timeline
# Prerequisites: setup-infra.sh, setup-alerts.sh, initial deploy-app.sh
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/.env.staging"
STAGING_URL="https://${APP_NAME}.azurewebsites.net"

source "$SCRIPT_DIR/.env.production"
PROD_URL="https://${APP_NAME}.azurewebsites.net"
PROD_APP="$APP_NAME"
PROD_RG="$RESOURCE_GROUP"

ts() { echo "[$(date +%H:%M:%S)]"; }

echo "╔══════════════════════════════════════════════╗"
echo "║  ShopFast SRE Demo — Automated Timeline      ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── T+0:00 — Baseline ──────────────────────────────
echo "$(ts) ▶ Step 1: Both environments healthy on v1.0.0"
echo "  Staging:    $STAGING_URL"
echo "  Production: $PROD_URL"
curl -sf "$STAGING_URL/api/health" | jq -c .
curl -sf "$PROD_URL/api/health" | jq -c .
echo "  Production orders (NULLs filtered by WHERE clause):"
curl -sf "$PROD_URL/api/orders" | jq -c '{count: .count}'
echo ""

# ── T+0:10 — Create bad PR ─────────────────────────
echo "$(ts) ▶ Step 2: Creating PR — 'feat: Add status badge system'"
bash "$SCRIPT_DIR/create-bad-pr.sh" 2>&1 | sed 's/^/  /'
echo ""

# ── T+0:30 — Merge PR ──────────────────────────────
echo "$(ts) ▶ Step 3: Merging PR (simulating CI/CD approval)"
cd "$PROJECT_ROOT"
PR_NUM=$(gh pr list --head feature/status-badges --json number -q '.[0].number')
if [[ -n "$PR_NUM" ]]; then
  gh pr merge "$PR_NUM" --squash --delete-branch --yes 2>&1 | sed 's/^/  /'
else
  echo "  (PR already merged or not found — continuing)"
fi
echo ""

# ── T+1:00 — Deploy to staging ─────────────────────
echo "$(ts) ▶ Step 4: Deploying v1.1.0 to staging"
# Swap in buggy version
cp "$PROJECT_ROOT/api/app.js" "$PROJECT_ROOT/api/app.js.bak"
cp "$PROJECT_ROOT/api/app-v1.1.0.js" "$PROJECT_ROOT/api/app.js"
bash "$SCRIPT_DIR/deploy-app.sh" staging 2>&1 | sed 's/^/  /'
echo ""
echo "$(ts) Testing staging..."
echo "  Health: $(curl -sf "$STAGING_URL/api/health" | jq -c .version)"
echo "  Orders: $(curl -sf "$STAGING_URL/api/orders" | jq -c '{count: .count}')"
echo "  Stats:  $(curl -sf "$STAGING_URL/api/stats" | jq -c '{orders: .orders}')"
echo "  ✅ Staging passes — clean data, no NULLs"
echo ""

# ── T+2:00 — Deploy to production staging slot ─────
echo "$(ts) ▶ Step 5: Deploying v1.1.0 to production staging slot"
bash "$SCRIPT_DIR/deploy-app.sh" production --slot staging 2>&1 | sed 's/^/  /'
echo ""
echo "$(ts) Testing production slot..."
SLOT_URL="https://${PROD_APP}-staging.azurewebsites.net"
echo "  Health: $(curl -sf "$SLOT_URL/api/health" | jq -c .version)"
echo "  ✅ Slot health check passes"
echo ""

# ── T+2:30 — Swap to production ────────────────────
echo "$(ts) ▶ Step 6: Swapping staging slot to production — 💥"
az webapp deployment slot swap \
  --name "$PROD_APP" --resource-group "$PROD_RG" \
  --slot staging --target-slot production -o none
echo "  Swap complete. v1.1.0 is now live in production."
echo ""

# Restore original app.js
cp "$PROJECT_ROOT/api/app.js.bak" "$PROJECT_ROOT/api/app.js"
rm "$PROJECT_ROOT/api/app.js.bak"

# ── T+3:00 — Production starts failing ─────────────
echo "$(ts) ▶ Step 7: Testing production — expecting failures"
sleep 10
echo "  Health: $(curl -sf "$PROD_URL/api/health" | jq -c .version 2>/dev/null || echo 'FAILED')"
echo "  Orders: $(curl -sf "$PROD_URL/api/orders" 2>/dev/null && echo 'OK' || echo '❌ 500 ERROR')"
echo "  Stats:  $(curl -sf "$PROD_URL/api/stats" 2>/dev/null && echo 'OK' || echo '❌ 500 ERROR')"
echo ""
echo "  💥 /api/orders and /api/stats crash on legacy NULL status rows"
echo "     TypeError: Cannot read properties of null (reading 'toLowerCase')"
echo "     Root cause: PR removed WHERE o.status IS NOT NULL filter"
echo ""

# ── T+3:30 — Generate traffic ──────────────────────
echo "$(ts) ▶ Step 8: Generating user traffic (triggering alerts)"
for i in $(seq 1 60); do
  curl -sf "$PROD_URL/api/orders" >/dev/null 2>&1 &
  curl -sf "$PROD_URL/api/stats" >/dev/null 2>&1 &
  curl -sf "$PROD_URL/api/products" >/dev/null 2>&1 &
  [[ $((i % 20)) -eq 0 ]] && echo "  $(ts) $((i*3)) requests sent..."
done
wait
echo "  ✓ 180 requests sent. 5xx errors flowing to App Insights."
echo ""

# ── T+4:00 — Wait for Dave ─────────────────────────
echo "$(ts) ▶ Step 9: Waiting for Dave to receive alert..."
echo "  Azure Monitor evaluates every 1 minute."
echo "  Alert fires when >3 5xx errors in 5-minute window."
echo ""
echo "  Expected Dave actions:"
echo "    1. 🔔 Receives webhook alert"
echo "    2. 🔍 Queries App Insights — finds TypeError on formatStatus()"
echo "    3. 🔗 Searches recent PRs — finds PR #42 removed WHERE clause"
echo "    4. 🔧 Creates fix PR — restores null check"
echo "    5. 📊 Posts incident report to Telegram"
echo ""
echo "$(ts) Demo timeline complete. Dave takes it from here."
