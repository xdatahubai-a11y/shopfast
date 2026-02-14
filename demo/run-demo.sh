#!/usr/bin/env bash
set -euo pipefail

#############################################################################
# ShopFast Demo — End-to-End: Bad PR → Prod Failure → Dave Investigates → Fix
#
# Prerequisites:
#   - Both environments deployed (run deploy/setup-staging.sh + deploy/setup-prod.sh)
#   - Dave onboarded and monitoring the production subscription
#   - GitHub repo initialized with v1.0.0 code
#
# Usage: ./run-demo.sh
#############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# These get set by the deploy scripts
STAGING_URL="${STAGING_URL:-http://localhost:3001}"
PROD_URL="${PROD_URL:-http://localhost:3000}"
GITHUB_REPO="${GITHUB_REPO:-xdatahubai-a11y/shopfast}"

log() { echo ""; echo "━━━ $(date +%H:%M:%S) $* ━━━"; }
pause() { echo ""; echo "  ▸ Press Enter to continue..."; read -r; }

#############################################################################
log "🎬 DEMO START — ShopFast E-Commerce"
echo ""
echo "  Staging:    $STAGING_URL"
echo "  Production: $PROD_URL"
echo "  Repo:       $GITHUB_REPO"
pause

#############################################################################
log "📋 Step 1: Show healthy production"
echo ""
echo "  Checking production health..."
curl -s "$PROD_URL/api/health" | jq .
echo ""
echo "  Fetching orders (all working, including legacy null-status orders)..."
curl -s "$PROD_URL/api/orders" | jq '.count, .orders[:3]'
pause

#############################################################################
log "🔧 Step 2: Developer creates PR — 'Improve order listing'"
echo ""
echo "  Creating feature branch..."
cd "$REPO_DIR"
git checkout -b feature/improve-order-listing 2>/dev/null || git checkout feature/improve-order-listing
cp api/app.bad.js api/app.js
git add api/app.js
git commit -m "feat: Add status filtering and formatting to orders endpoint

- Add ?status= query parameter for filtering orders
- Format status badges with proper capitalization  
- Add status breakdown to dashboard stats
- Improve UI with color-coded status badges

Tested locally with sample data — all endpoints working." 2>/dev/null || true

echo "  Pushing branch and creating PR..."
git push origin feature/improve-order-listing -f 2>/dev/null
PR_URL=$(gh pr create --title "feat: Improve order listing with status filtering" \
  --body "## Changes
- Add \`?status=\` query parameter for filtering orders
- Format status badges with proper capitalization  
- Add status breakdown to dashboard stats
- Improve UI with color-coded status badges

## Testing
- ✅ Unit tests pass
- ✅ Tested locally with sample data
- ✅ All endpoints return correct data
- ✅ Status filter works: \`/api/orders?status=pending\`" \
  --base main 2>/dev/null || echo "PR already exists")
echo "  PR: $PR_URL"
pause

#############################################################################
log "✅ Step 3: PR merged and deployed to STAGING"
echo ""
echo "  Merging PR..."
gh pr merge --squash --auto 2>/dev/null || gh pr merge --squash 2>/dev/null || echo "  (merge manually if needed)"
git checkout main && git pull 2>/dev/null || true

echo "  Deploying v1.1.0 to staging..."
# TODO: Update staging container with bad code
echo "  (Deploy command here — updates staging container image)"
sleep 2

echo ""
echo "  Testing staging..."
curl -s "$STAGING_URL/api/health" | jq .
echo ""
echo "  Staging orders (clean data — no nulls — ALL PASS ✅):"
curl -s "$STAGING_URL/api/orders" | jq '.count'
echo "  Stats:"
curl -s "$STAGING_URL/api/stats" | jq .
echo ""
echo "  ✅ Staging looks good! Promoting to production..."
pause

#############################################################################
log "🚀 Step 4: Deploy to PRODUCTION"
echo ""
echo "  Deploying v1.1.0 to production..."
# TODO: Update production container with bad code
echo "  (Deploy command here — updates prod container image)"
sleep 2
echo "  Production deploy complete."
pause

#############################################################################
log "💥 Step 5: PRODUCTION BREAKS"
echo ""
echo "  Simulating real traffic hitting the orders endpoint..."
echo "  (This will fail because production has legacy orders with NULL status)"
echo ""
for i in $(seq 1 20); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$PROD_URL/api/orders")
  if [ "$HTTP_CODE" = "500" ]; then
    echo "  Request $i: ❌ HTTP 500"
  else
    echo "  Request $i: ✅ HTTP $HTTP_CODE"
  fi
  sleep 0.5
done

echo ""
echo "  Also hitting stats endpoint..."
for i in $(seq 1 10); do
  curl -s -o /dev/null -w "  Stats request $i: HTTP %{http_code}\n" "$PROD_URL/api/stats"
  sleep 0.5
done

echo ""
echo "  🔴 Production is failing! Errors flowing into App Insights..."
echo "  Azure Monitor alert will fire within 5 minutes → webhook to Dave"
pause

#############################################################################
log "🤖 Step 6: DAVE RECEIVES ALERT (automatic)"
echo ""
echo "  Waiting for Dave to receive the webhook alert and start investigating..."
echo "  Watch Dave's Telegram for updates."
echo ""
echo "  Expected Dave actions:"
echo "    1. Receive webhook alert: 'High error rate on shopfast-prod'"
echo "    2. Query App Insights → find TypeError: Cannot read properties of null"
echo "    3. Check recent deployments → v1.1.0 just deployed"
echo "    4. Check git log → find PR 'Improve order listing'"
echo "    5. Read the diff → spot missing null check in formatStatus()"
echo "    6. Create fix PR → add null guard to formatStatus()"
echo "    7. Report on Telegram with INC-NNN"
echo ""
echo "  ⏳ This happens autonomously. Watch Telegram..."
pause

#############################################################################
log "🎬 DEMO COMPLETE"
echo ""
echo "  Timeline:"
echo "    T+0:00  PR created and merged"
echo "    T+0:30  Deployed to staging (passed ✅)"
echo "    T+1:00  Deployed to production"
echo "    T+1:30  Production errors begin"
echo "    T+5:00  Azure alert fires → Dave receives webhook"
echo "    T+6:00  Dave investigates, correlates with PR"
echo "    T+8:00  Dave creates fix PR"
echo "    T+9:00  Dave reports INC-001 on Telegram"
echo ""
echo "  Key insight: The bug passed staging because staging has clean data."
echo "  Production has legacy orders with NULL status from a 2023 migration."
echo "  Dave found this in minutes — without human intervention."
