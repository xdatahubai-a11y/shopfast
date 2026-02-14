# ShopFast — SRE Demo App

A realistic e-commerce app designed to demonstrate AI-powered SRE incident response.

## The Scenario

A developer adds status badges to the order dashboard (PR #42). They test against staging — looks great. They deploy to production — it crashes. Why?

**Staging** has clean data: every order has a status (`pending`, `shipped`, etc.).
**Production** has legacy data from a 2023 migration: some orders have `NULL` status.

The new `formatStatus()` function calls `.toLowerCase()` on the status field. `null.toLowerCase()` = 💥

## Architecture

```
shopfast-staging-rg          shopfast-prod-rg
├── Azure SQL (clean data)   ├── Azure SQL (legacy NULLs)
├── App Insights             ├── App Insights → Alert → Dave webhook
├── Container Instance       └── Container Instance
└── ACR                          └── ACR
```

## Demo Flow

1. `setup-demo.sh` — Deploy both environments with v1.0.0 (safe)
2. `create-bad-pr.sh` — Create PR #42 on GitHub
3. `deploy-bad-pr.sh` — Deploy v1.1.0 to both (staging passes, prod crashes)
4. `setup-alerts.sh` — Wire App Insights alerts to Dave's webhook
5. Traffic hits production → 500s → alert fires → Dave investigates

Or use `run-demo.sh` for the guided walkthrough.

## What Dave Does

1. **Receives alert** via webhook (Azure Monitor → action group → Dave)
2. **Investigates** — queries App Insights, finds `TypeError: Cannot read properties of null (reading 'toLowerCase')`
3. **Correlates to code** — finds PR #42 introduced `formatStatus()`, identifies the null-safety gap
4. **Creates fix PR** — adds `status = status || 'unknown'` before the `.toLowerCase()` call
5. **Reports on Telegram** — full incident report with timeline, root cause, and fix

## Files

```
api/
  app.js          — v1.0.0 (safe, handles NULLs)
  app-v1.1.0.js   — v1.1.0 (buggy, crashes on NULLs)
  public/         — React SPA dashboard
  Dockerfile
db/
  schema.sql          — Table definitions
  seed-staging.sql    — Clean data
  seed-production.sql — Legacy data with NULLs
deploy/
  setup-demo.sh     — Infrastructure setup
  create-bad-pr.sh  — Create the bad PR on GitHub
  deploy-bad-pr.sh  — Deploy v1.1.0 to both envs
  setup-alerts.sh   — Wire alerts to Dave
  run-demo.sh       — Full guided demo
  teardown.sh       — Delete everything
```

## Cost

~$15-20/day when running (2x SQL Basic, 2x ACI, 2x ACR Basic, 2x App Insights).
Run `teardown.sh` when done.
