# ShopFast — Enterprise SRE Demo

A realistic e-commerce platform demonstrating AI-powered SRE incident detection, investigation, and resolution.

## The Scenario

A developer adds status badges to the order dashboard (PR #42). They remove a `WHERE o.status IS NOT NULL` filter from the SQL query to "show all orders for the new dashboard." They test against staging — looks great. CI/CD deploys to production via slot swap — it crashes.

**Why?** Production has legacy orders from a 2023 data migration with `NULL` status fields. The SQL filter was the only thing keeping those rows out. The new `formatStatus()` function calls `.toLowerCase()` on null.

**Staging** has clean seed data — every order has a status. No NULLs, no problem.  
**Production** has real-world legacy data — 5 orders with NULL status from an old system migration.

## Architecture

```
GitHub Actions CI/CD
  push to main → build → deploy staging → deploy prod slot → swap to production

shopfast-staging-rg                    shopfast-prod-rg
├── App Service Plan (B1)              ├── App Service Plan (B1)
├── App Service (shopfast-staging)     ├── App Service (shopfast-prod)
├── Azure SQL (clean data)             │   ├── Production slot
├── App Insights                       │   └── Staging slot (pre-swap)
└── Log Analytics                      ├── Azure SQL (legacy NULL data)
                                       ├── App Insights → Alert → Dave webhook
                                       └── Log Analytics
```

## Demo Flow (~10 minutes)

| Time | Event |
|------|-------|
| T+0 | Both environments healthy on v1.0.0 |
| T+1 | Developer creates PR #42: "Add status badge system" |
| T+2 | PR merged → CI/CD deploys to staging → passes |
| T+3 | CI/CD deploys to production staging slot → health check passes |
| T+4 | Slot swap to production → **💥 orders/stats endpoints crash** |
| T+5 | User traffic generates 500s → App Insights → Azure Monitor alert |
| T+6 | Dave receives webhook, begins investigation |
| T+8 | Dave traces error → formatStatus() → removed WHERE clause → PR #42 |
| T+9 | Dave creates fix PR restoring null safety |
| T+10 | Incident report posted to Telegram |

## Quick Start

```bash
# 1. Provision infrastructure (~15 min)
cd deploy
./setup-infra.sh

# 2. Initial deploy of v1.0.0 to both environments
./deploy-app.sh staging
./deploy-app.sh production

# 3. Wire alerts to Dave
DAVE_WEBHOOK_URL=https://your-dave.azurewebsites.net/hooks/wake ./setup-alerts.sh

# 4. Run the demo
./run-demo.sh

# 5. Clean up
./teardown.sh
```

## Project Structure

```
api/
  app.js            v1.0.0 — safe (WHERE IS NOT NULL filters legacy rows)
  app-v1.1.0.js     v1.1.0 — buggy (removes filter, adds formatStatus)
  public/           Built frontend (copied from frontend/dist)
  Dockerfile
frontend/
  src/              React + Tailwind admin dashboard
  vite.config.js    Vite build config
db/
  schema.sql        Table definitions (customers, products, orders, order_items)
  seed-staging.sql  Clean data — all fields populated
  seed-production.sql  Legacy data — NULL status, tier, addresses
deploy/
  setup-infra.sh    Provision both environments
  deploy-app.sh     Build + deploy to any environment/slot
  create-bad-pr.sh  Create PR #42 on GitHub
  setup-alerts.sh   Wire App Insights alerts to Dave
  run-demo.sh       Full automated demo timeline
  teardown.sh       Delete everything
.github/workflows/
  deploy.yml        Real CI/CD pipeline (build → staging → slot swap → prod)
```

## Cost

~$20-25/day when running (2× App Service B1, 2× SQL Basic, 2× App Insights).  
Run `deploy/teardown.sh` when done.
