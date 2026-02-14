#!/usr/bin/env bash
set -euo pipefail

# Create a realistic-looking PR on GitHub that introduces the v1.1.0 bug
# This is what Dave will correlate the production failure back to

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRIPT_DIR/.."
cd "$REPO_DIR"

BRANCH="feature/status-badges"
echo "=== Creating Bad PR: $BRANCH ==="

# Ensure we're on main and up to date
git checkout main 2>/dev/null || git checkout -b main
git pull origin main 2>/dev/null || true

# Create feature branch
git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"

# Swap in the buggy version
cp api/app-v1.1.0.js api/app.js

# Stage and commit with a realistic commit message
git add api/app.js
git commit -m "feat: add status badge system for order display

- Add color-coded status badges (pending=amber, confirmed=blue, shipped=purple, delivered=green, cancelled=red)
- Add ?status= query parameter for filtering orders
- Add status breakdown to /api/stats for dashboard charts
- Improve order display with formatted status labels

Tested locally with staging database — all orders display correctly."

# Push and create PR
git push -u origin "$BRANCH"
gh pr create \
  --title "feat: Add status badge system for order display" \
  --body "## Summary
Adds a visual status badge system to the orders API for better dashboard UX.

### Changes
- \`formatStatus()\` function maps order statuses to color-coded badges
- \`GET /api/orders?status=shipped\` — new filter parameter
- \`GET /api/stats\` now includes \`byStatus\` breakdown for charts
- Consistent status formatting across all order endpoints

### Testing
- ✅ Tested against staging database
- ✅ All 5 status types display correctly
- ✅ Filter parameter works as expected
- ✅ Stats endpoint returns correct breakdown

### Screenshots
Status badges render as colored pills in the dashboard." \
  --base main

# Switch back to main and restore
git checkout main
echo ""
echo "=== PR Created ==="
echo "Branch: $BRANCH"
echo "The commit message says 'tested with staging database' — that's the tell."
echo "Staging has clean data (no NULLs). Production has legacy NULL status rows."
