---
name: fabric-monitoring-operations
description: Fabric run monitoring and operations — run-status polling, failure/SLA/DQ alerting, capacity health, runbooks, safe re-run. Use when defining or operating monitoring for Fabric pipelines and notebooks.
---

# Fabric monitoring & operations

Applies FABRIC_STANDARDS.md (Observability and Operations) plus OBSERVABILITY_STANDARDS.md.

## Signals
| Signal | Source |
|---|---|
| Run status/duration per pipeline & notebook | Monitor hub; Job Scheduler REST API (`.../workspaces/{id}/items/{id}/jobs/instances`); workspace monitoring if enabled |
| Row counts, reconciliation, DQ outcome | Control/audit Delta table written by the pipeline (run context fields) |
| Capacity throttling / utilization | Fabric Capacity Metrics app |
| Freshness | `max(_ingested_at)` per gold/silver table vs SLA |

Verify each API/feature exists in the tenant and its current shape before relying on it.

## Procedure
1. Read the SDD (SLA, schedule, owners, retention) and the pipelines' run-context fields.
2. Define the **alert catalog** (table in `fabric/ops/alerts.md` or as-code): failure, SLA breach (late/over-long), zero-row load, DQ FAIL, capacity throttling. Each: condition, severity, owner channel, first action.
3. Implement checks as small notebooks/pipelines or KQL/queries against the audit table; route via Teams/email/Web activity or Data Activator. Alert payloads carry ids and counts only — never data rows.
4. Write a **runbook per scheduled pipeline**: symptom → first checks → safe re-run (window params, idempotent) → escalation → known failure modes.
5. Weekly/periodic health report: success rate, p95 duration, freshness lag, capacity peaks (aggregated, no sensitive data).
6. Test: force a failure and a late run in test; confirm alert arrives with correct owner and run context.

## Do not
Change pipeline/notebook business logic (report to the owner instead); auto-remediate by editing prod items; export run data containing source values.
