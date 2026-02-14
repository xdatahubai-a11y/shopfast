#!/usr/bin/env bash
set -euo pipefail

#############################################################################
# ShopFast Demo — End-to-End Incident Response
#
# Flow:
#   1. Show healthy production app
#   2. Developer creates PR "Improve order status display"
#   3. PR merges → deploys to staging → passes
#   4. Deploys to production → starts failing (NULL status in legacy data)
#   5. Dave detects errors via App Insights alert
#   6. Dave investigates → correlates with the bad PR
#   7. Dave creates fix PR on GitHub
#   8. Dave creates incident (GitHub Issue) with full details
#   9. Dave asks for human approval to deploy fix
#
# Usage: ./run-demo.sh
#############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_DIR/deploy/config.sh"

STAGING_IP=$(cat /tmp/shopfast-staging-ip.txt 2>/dev/null || echo "")
PROD_IP=$(cat /tmp/shopfast-prod-ip.txt 2>/dev/null || echo "")
STAGING_URL="http://${STAGING_IP}:3000"
PROD_URL="http://${PROD_IP}:3000"

log() { echo ""; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; echo "  $(date +%H:%M:%S)  $*"; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }
pause() { echo ""; echo "  ▶ Press Enter to continue..."; read -r; }

clear
echo ""
echo "  ⚡ ShopFast — AI SRE Demo"
echo "  ─────────────────────────"
echo "  Staging:    $STAGING_URL"
echo "  Production: $PROD_URL"
echo "  Repo:       https://github.com/$GITHUB_REPO"
echo ""
echo "  Dave is watching production via App Insights + webhook alerts."
echo ""
pause

#############################################################################
log "📋 STEP 1 — Show healthy production"

echo ""
echo "  Production health check:"
curl -s "$PROD_URL/api/health" | jq .
echo ""
echo "  Dashboard stats:"
curl -s "$PROD_URL/api/stats" | jq .
echo ""
echo "  Recent orders (note: legacy orders have status displayed as 'unknown'):"
curl -s "$PROD_URL/api/orders" | jq '.orders[:5] | .[] | {id, customer, status, total}'
echo ""
echo "  ✅ Everything working. 10 orders including 5 legacy ones with null status."
pause

#############################################################################
log "🔧 STEP 2 — Developer creates PR"

echo ""
echo "  A developer wants to improve the order listing UI."
echo "  They add status formatting (capitalize, color badges) and filtering."
echo ""
echo "  Creating feature branch..."

cd "$REPO_DIR"
# Reset to clean state
git checkout main 2>/dev/null && git pull 2>/dev/null || true
git branch -D feature/improve-order-listing 2>/dev/null || true

# Create the bad branch
git checkout -b feature/improve-order-listing
cp api/app.bad.js api/app.js
git add api/app.js
git commit -m "feat: Add status filtering and formatting to orders endpoint

- Add ?status= query parameter for filtering orders
- Format status badges with proper capitalization (formatStatus helper)
- Add color-coded status badges for UI
- Add status breakdown to dashboard stats endpoint

Tested with local dev data — all endpoints returning correct responses."

echo "  Pushing and creating PR..."
git push origin feature/improve-order-listing -f 2>/dev/null

gh pr create \
  --title "feat: Improve order listing with status filtering & formatting" \
  --body "## What Changed
- Added \`formatStatus()\` helper to capitalize order status for UI display
- Added \`getStatusColor()\` for color-coded status badges
- Added \`?status=\` query parameter to filter orders
- Added status breakdown to \`/api/stats\` endpoint

## Testing
- ✅ All API endpoints return correct data
- ✅ Status filter works: \`GET /api/orders?status=pending\`
- ✅ Dashboard stats include status breakdown
- ✅ No breaking changes to existing response format

## Screenshots
Status badges now show properly formatted: \`Pending\`, \`Shipped\`, \`Delivered\` etc." \
  --base main 2>/dev/null || echo "  PR already exists"

echo ""
echo "  PR created. Developer tested locally — works fine."
echo "  Code review passes. Merging..."
pause

#############################################################################
log "🔀 STEP 3 — PR merges, deploys to STAGING"

echo ""
gh pr merge --squash -d 2>/dev/null || echo "  (merging...)"
git checkout main && git pull 2>/dev/null

echo "  Deploying v1.1.0 to staging..."
"$REPO_DIR/deploy/push-code.sh" --env staging --bad --version 1.1.0 2>&1 | tail -3

echo ""
echo "  Testing staging..."
sleep 10
echo "  Health:"
curl -s "$STAGING_URL/api/health" | jq .
echo ""
echo "  Orders (staging has clean data — no nulls):"
STAGING_ORDERS=$(curl -s "$STAGING_URL/api/orders")
echo "$STAGING_ORDERS" | jq '.count'
echo "$STAGING_ORDERS" | jq '.orders[:3] | .[] | {id, customer, status, total}'
echo ""
echo "  Stats:"
curl -s "$STAGING_URL/api/stats" | jq .
echo ""
echo "  ✅ Staging passes! All orders have proper status. Promoting to production..."
pause

#############################################################################
log "🚀 STEP 4 — Deploy to PRODUCTION"

echo ""
echo "  Deploying v1.1.0 to production..."
"$REPO_DIR/deploy/push-code.sh" --env prod --bad --version 1.1.0 2>&1 | tail -3

echo ""
echo "  Waiting for container to start..."
sleep 15
echo "  Health check:"
curl -s "$PROD_URL/api/health" | jq .
pause

#############################################################################
log "💥 STEP 5 — PRODUCTION FAILS"

echo ""
echo "  Sending real traffic to production..."
echo "  (Legacy orders with NULL status will crash formatStatus())"
echo ""

FAIL=0
for i in $(seq 1 30); do
  CODE=$(curl -s -o /tmp/shopfast-resp.json -w "%{http_code}" "$PROD_URL/api/orders" 2>/dev/null)
  if [ "$CODE" = "500" ]; then
    ((FAIL++))
    echo "  Request $i: ❌ HTTP 500 — $(cat /tmp/shopfast-resp.json | jq -r '.error' 2>/dev/null)"
  else
    echo "  Request $i: ✅ HTTP $CODE"
  fi
  sleep 0.3
done

echo ""
echo "  Also hitting stats endpoint..."
for i in $(seq 1 15); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "$PROD_URL/api/stats")
  [ "$CODE" = "500" ] && echo "  Stats $i: ❌ HTTP 500" || echo "  Stats $i: ✅ HTTP $CODE"
  sleep 0.3
done

echo ""
echo "  🔴 Production is DOWN. $FAIL/30 order requests failed."
echo "  Errors are flowing into App Insights."
echo "  Azure Monitor alert will fire → webhook → Dave"
echo ""

# Keep generating traffic in background
echo "  Starting background traffic..."
"$SCRIPT_DIR/traffic.sh" "$PROD_URL" --rate 2 --duration 600 > /tmp/shopfast-traffic.log 2>&1 &
TRAFFIC_PID=$!
echo "  Traffic PID: $TRAFFIC_PID (will run for 10 min)"
pause

#############################################################################
log "🤖 STEP 6 — DAVE RESPONDS (autonomous)"

echo ""
echo "  Dave should now:"
echo ""
echo "  1. 📨 Receive webhook alert"
echo "     → 'ShopFast production: high error rate — 500 errors on /api/orders'"
echo ""
echo "  2. 🔍 Investigate App Insights"
echo "     → Query exceptions table"
echo "     → Find: TypeError: Cannot read properties of null (reading 'charAt')"
echo "     → Stack trace points to formatStatus() in app.js"
echo ""
echo "  3. 📋 Check recent deployments"
echo "     → Production just updated from v1.0.0 → v1.1.0"
echo "     → Staging (v1.1.0) is healthy — data-dependent issue"
echo ""
echo "  4. 🔗 Correlate with git history"
echo "     → Find the squash commit 'feat: Improve order listing...'"
echo "     → Read the diff — see formatStatus() has no null guard"
echo "     → Compare staging seed (clean) vs production seed (nulls)"
echo ""
echo "  5. 🛠️  Create fix PR on GitHub"
echo "     → Branch: fix/null-status-handling"
echo "     → Add null check: status ? formatStatus(status) : 'Unknown'"
echo "     → PR links to incident"
echo ""
echo "  6. 🎫 Create GitHub Issue (incident)"
echo "     → INC-001: Production order-api failure"
echo "     → Root cause: PR #N introduced null-unsafe formatStatus()"
echo "     → Impact: /api/orders and /api/stats returning 500"
echo "     → Fix: PR #M (awaiting approval)"
echo "     → Timeline with all steps"
echo ""
echo "  7. 👤 Ask for human approval"
echo "     → 'Fix PR ready. Approve to merge and redeploy?'"
echo ""
echo "  ━━━ Watch Dave's Telegram messages ━━━"
echo ""
echo "  Press Enter after Dave has created the incident and fix PR..."
pause

#############################################################################
log "✅ STEP 7 — Human approves fix PR"

echo ""
echo "  Review Dave's fix PR on GitHub."
echo "  Tell Dave on Telegram: 'Approved, go ahead'"
echo ""
echo "  Dave will then:"
echo "    1. Merge the fix PR"
echo "    2. Ask for deployment approval"
echo ""
echo "  Press Enter after you've approved the fix PR..."
pause

#############################################################################
log "🚀 STEP 8 — Dave deploys the fix"

echo ""
echo "  Dave will:"
echo "    1. Deploy v1.1.1 to production"
echo "    2. Wait for container to be healthy"
echo "    3. Hit /api/orders to verify the fix"
echo "    4. Query App Insights to confirm error rate dropping"
echo ""
echo "  Watch Telegram for Dave's deployment updates..."
echo ""
echo "  Press Enter after Dave confirms the fix is working..."
pause

#############################################################################
log "📝 STEP 9 — Dave updates incident & writes RCA"

echo ""
echo "  Dave will now:"
echo "    1. Update the GitHub Issue with resolution timeline"
echo "    2. Close the incident as resolved"
echo "    3. Write Root Cause Analysis:"
echo ""
echo "       Root Cause: formatStatus() in app.js called .charAt(0) on null"
echo "       Why staging missed it: staging has clean data, no NULL status"
echo "       Production has legacy orders from 2023 migration with NULL status"
echo ""
echo "    4. Create follow-up action items:"
echo "       → 'Add NULL test data to staging seed'"
echo "       → 'Add defensive null checks to all data transforms'"
echo "       → 'Add integration tests with production-like data'"
echo ""
echo "  Watch Telegram + GitHub for Dave's updates..."
echo ""
echo "  Press Enter after Dave completes the RCA..."
pause

# Kill background traffic
kill $TRAFFIC_PID 2>/dev/null || true

#############################################################################
log "✅ STEP 10 — Verify everything is clean"

echo ""
echo "  Production health:"
curl -s "$PROD_URL/api/health" | jq .
echo ""
echo "  Orders (should work now, including legacy NULL → 'Unknown'):"
curl -s "$PROD_URL/api/orders" | jq '.orders[:5] | .[] | {id, customer, status, total}'
echo ""
echo "  Stats:"
curl -s "$PROD_URL/api/stats" | jq .
echo ""
echo "  GitHub incident (closed with RCA):"
echo "  https://github.com/$GITHUB_REPO/issues"
echo ""
echo "  ✅ Production healthy. Incident resolved. RCA complete."

#############################################################################
log "🎬 DEMO COMPLETE"

echo ""
echo "  Full Timeline:"
echo "  ──────────────────────────────────────────────────────────"
echo "  T+0:00   Developer creates PR (status formatting)"
echo "  T+0:30   PR merges → deploys to staging"
echo "  T+1:00   Staging passes ✅ (clean data, no nulls)"
echo "  T+1:30   Deploys to production"
echo "  T+2:00   Production fails 🔴 (legacy NULL data)"
echo "  T+5:00   Azure alert fires → webhook → Dave"
echo "  T+6:00   Dave queries App Insights → TypeError on null"
echo "  T+7:00   Dave correlates with recent PR → finds formatStatus()"
echo "  T+8:00   Dave creates fix PR + GitHub incident (INC-001)"
echo "  T+9:00   Dave asks for human approval"
echo "  T+9:30   Human approves → Dave merges PR"
echo "  T+10:00  Dave deploys v1.1.1 to production"
echo "  T+10:30  Dave verifies fix — error rate 0%"
echo "  T+11:00  Dave updates incident, writes RCA, creates action items"
echo "  T+11:30  Incident closed ✅"
echo "  ──────────────────────────────────────────────────────────"
echo ""
echo "  What Dave did autonomously:"
echo "    ✅ Detected production failure within minutes"
echo "    ✅ Investigated App Insights → found exact error + stack trace"
echo "    ✅ Correlated with git history → identified the bad PR"
echo "    ✅ Understood WHY staging passed (data difference)"
echo "    ✅ Created a targeted fix PR (not just a revert)"
echo "    ✅ Filed incident with full context"
echo "    ✅ Waited for human approval (never auto-deployed)"
echo "    ✅ Deployed and verified the fix"
echo "    ✅ Wrote RCA with prevention recommendations"
echo "    ✅ Created follow-up action items"
echo ""
echo "  What required a human:"
echo "    👤 Approve the fix PR"
echo "    👤 Approve production deployment"
echo ""
echo "  No one had to wake up at 3am to debug this."
echo ""
