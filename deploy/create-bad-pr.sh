#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# create-bad-pr.sh — Create PR #42 with the buggy v1.1.0 code
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

BRANCH="feature/status-badges"

echo "=== Creating Bad PR ==="

cd "$PROJECT_ROOT"

# Ensure we're on main and up to date
git checkout main
git pull origin main 2>/dev/null || true

# Create feature branch
echo "Creating branch: $BRANCH"
git checkout -b "$BRANCH"

# Copy the buggy app version
echo "Applying v1.1.0 changes..."
cp api/app-v1.1.0.js api/app.js

# Commit with a realistic message
git add api/app.js
git commit -m "feat: add order status badges and stats endpoint

- Added color-coded status badges to order list
- New /api/stats endpoint for dashboard metrics
- Refactored order queries for better performance
- Tested against staging database ✅"

# Push and create PR
echo "Pushing branch and creating PR..."
git push origin "$BRANCH"

gh pr create \
  --title "Add order status badges and stats dashboard" \
  --body "## Changes

- ✨ Color-coded status badges on the orders page
- 📊 New \`/api/stats\` endpoint for the dashboard
- ⚡ Refactored SQL queries for better performance

## Testing

- [x] Tested against staging database
- [x] All endpoints return 200
- [x] Frontend renders badges correctly

Closes #41" \
  --base main \
  --head "$BRANCH"

echo "Switching back to main..."
git checkout main

echo ""
echo "✅ PR created on branch '$BRANCH'"
echo "   Ready to merge when demo starts"
