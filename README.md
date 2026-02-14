# ShopFast — E-Commerce Demo App

A realistic e-commerce application used to demonstrate AI-powered SRE (Dave) detecting and investigating production incidents.

## The Demo Story

1. **Developer** creates a PR: "Improve order listing with status filtering"
2. **PR merges** → deploys to **staging** → all tests pass ✅
3. Promotes to **production** → starts **failing** 🔴
4. **Dave** (AI SRE) receives alert → investigates → finds the bad PR → creates fix PR

### Why It Fails in Production But Not Staging

The PR adds a `formatStatus()` function that calls `.charAt(0)` on the order status field. Staging has clean test data where every order has a status. Production has **legacy orders from a 2023 migration** where `status` is `NULL`. The null causes `TypeError: Cannot read properties of null (reading 'charAt')`.

## Architecture

```
┌──────────────────────────────────────────────┐
│  Staging (shopfast-staging-rg)               │
│  ┌────────┐  ┌─────────┐  ┌──────────────┐  │
│  │  UI    │──│  API    │──│  SQL (Basic)  │  │
│  │(static)│  │(Node.js)│  │  Clean data   │  │
│  └────────┘  └─────────┘  └──────────────┘  │
│                    │                          │
│              App Insights                     │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│  Production (shopfast-prod-rg)               │
│  ┌────────┐  ┌─────────┐  ┌──────────────┐  │
│  │  UI    │──│  API    │──│  SQL (Basic)  │  │
│  │(static)│  │(Node.js)│  │  Legacy nulls │  │
│  └────────┘  └─────────┘  └──────────────┘  │
│                    │                          │
│              App Insights → Alert → Dave 🤖   │
└──────────────────────────────────────────────┘
```

## Quick Start

```bash
# 1. Deploy infrastructure
cd deploy && ./setup.sh

# 2. Run the demo
cd demo && ./run-demo.sh

# 3. Clean up
cd deploy && ./teardown.sh
```

## Files

| Path | Description |
|------|-------------|
| `api/app.js` | Working API (v1.0.0) — handles nulls gracefully |
| `api/app.bad.js` | Buggy API (v1.1.0) — crashes on NULL status |
| `api/public/index.html` | Dashboard UI |
| `db/schema.sql` | Database schema |
| `db/seed-staging.sql` | Clean test data (no nulls) |
| `db/seed-production.sql` | Production data with legacy NULL records |
| `deploy/setup.sh` | Full infrastructure deployment |
| `deploy/push-code.sh` | Deploy code to staging or prod |
| `deploy/teardown.sh` | Delete all Azure resources |
| `demo/run-demo.sh` | Interactive demo script |
| `demo/traffic.sh` | Realistic traffic generator |

## Cost

~$10-15/day when running (2× SQL Basic + 2× Container Instance). Teardown to $0.
