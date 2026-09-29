# Fabric Standards

## Purpose

Defines what "production-grade" means for PyTIQ Data Engineering work that runs
on **Microsoft Fabric**: Data Factory pipelines, Dataflow Gen2, notebooks,
Lakehouse/Warehouse items, OneLake, workspace/Git/deployment-pipeline promotion,
and run monitoring. It specializes — it does not replace — the shared PyTIQ
standards.

## Scope

Applies to a workstream only when its SDD (§14 Deployment Implications and §18
Required Specialists) selects Fabric as the execution target. It covers Fabric
items and their lifecycle. Generic pipeline design, connector contracts,
transformation logic, DQ semantics and secrets policy remain owned by the
standards linked below.

## Referenced Standards

| Concern | Owning document (do not restate here) |
|---|---|
| Idempotency, restartability, schema drift, lineage | [DATA_ENGINEERING_STANDARDS.md](DATA_ENGINEERING_STANDARDS.md) |
| Write modes, retry-safety, reconciliation | [SINK_CONNECTOR_STANDARDS.md](SINK_CONNECTOR_STANDARDS.md) |
| Extraction modes, incremental state, retries | [SOURCE_CONNECTOR_STANDARDS.md](SOURCE_CONNECTOR_STANDARDS.md) |
| Business-rule logic, determinism | [TRANSFORMATION_STANDARDS.md](TRANSFORMATION_STANDARDS.md) |
| DQ outcomes, thresholds, quarantine | [DATA_QUALITY_STANDARDS.md](DATA_QUALITY_STANDARDS.md) |
| Secrets, identity, PII, masking | [SECURITY_AND_PII_STANDARDS.md](SECURITY_AND_PII_STANDARDS.md) |
| Typed config, environment overrides | [CONFIGURATION_STANDARDS.md](CONFIGURATION_STANDARDS.md) |
| Structured logging, metrics, run context | [OBSERVABILITY_STANDARDS.md](OBSERVABILITY_STANDARDS.md) |
| CI gates, promotion, rollback | [DEPLOYMENT_STANDARDS.md](DEPLOYMENT_STANDARDS.md) |
| Python in notebooks | [PYTHON_STANDARDS.md](PYTHON_STANDARDS.md) |

Proportionality (`ENGINEERING_STANDARDS.md` rule 21) applies to every rule
below: a rule with a trigger ("MUST when production-deployed") applies only once
the trigger holds; a rule with no trigger is unconditional.

## Principles

- Fabric items are **source-controlled artifacts**, not hand-built objects.
  The workspace is a deployment target; Git is the source of truth.
- Every item is **environment-neutral**. Environment differences live in
  parameters / variable libraries / deployment rules, never in item logic.
- Orchestration (pipelines) moves and sequences; **logic lives in notebooks or
  Dataflows**, not in pipeline expressions.
- Pick the lightest Fabric item that satisfies the SDD (see Item Selection).

## Item Selection

| Need | Use | Avoid |
|---|---|---|
| Bulk copy source → OneLake/Lakehouse/Warehouse, no row logic | Pipeline **Copy activity** | Notebook for a pure copy |
| Sequencing, dependencies, retries, schedules, parameter fan-out | **Data pipeline** | Encoding business logic in expressions |
| Complex/large-scale transformation, Delta merge, custom code | **Spark notebook** | Dataflow for multi-GB heavy joins |
| Low-code shaping by analysts, small/medium volume | **Dataflow Gen2** | Dataflow when logic needs unit tests or Delta MERGE control |
| Streaming/real-time ingestion | **Eventstream** (+ Eventhouse/Lakehouse) | Polling pipelines faster than the source supports |
| Query-only SQL consumption | Lakehouse **SQL analytics endpoint** / Warehouse | Writing through the SQL endpoint (read-only) |

## Workspace, Git and Environments

1. **One workspace per environment** (dev, test, prod) per solution. Prod MUST
   NOT be edited in the UI; changes arrive only through the promotion path.
2. **Git integration** connects dev only; test/prod are populated by the
   deployment pipeline or `fabric-cicd`-style release from the main branch. MUST when production-deployed.
3. Item folders in Git keep Fabric's generated layout (`<Name>.<ItemType>/`
   containing `.platform` plus the item definition, e.g. `pipeline-content.json`,
   `notebook-content.py`). Never hand-edit `.platform` logical IDs.
4. **Workspace folders** map to subfolders in Git; use them to group by domain
   and layer, not to encode environment.
5. Workspace roles follow least privilege (Viewer/Contributor/Member/Admin).
   Human Admin on prod is break-glass only. Pipelines run under a **service
   principal or workspace identity**, never a personal account.
6. Per-workstream capacity is named in the SDD; a workload MUST state which
   capacity (SKU) it targets and its expected peak concurrency.

## OneLake, Lakehouse and Delta

1. **Medallion layering**: `bronze` (raw, append-only, source-shaped, plus audit
   columns), `silver` (typed, deduplicated, conformed), `gold` (consumption /
   business-shaped). Each layer is a separate schema (schema-enabled Lakehouse)
   or a separate Lakehouse; do not mix layers in one schema.
2. **Table naming**: lowercase `snake_case`; `<domain>_<entity>` inside a layer
   schema; no spaces or special characters (they break the SQL endpoint).
3. All managed tables are **Delta**. Write with explicit mode — `append`,
   `overwrite` with partition predicate, or `MERGE` on a declared business key.
   Blind full-table `overwrite` of a table other consumers read is prohibited
   unless the SDD states it and downstream is quiesced.
4. **Idempotency**: every write MUST be safe to re-run for the same
   run-window (merge on key, or overwrite of a deterministic partition).
   Append-only bronze MUST carry `_ingest_run_id` and `_ingested_at` so a
   re-run can be detected and deduplicated.
5. **Schema drift**: classify per `DATA_ENGINEERING_STANDARDS.md` rule 14.
   `mergeSchema` / `overwriteSchema` MUST NOT be enabled globally; enable per
   write only when the SDD permits additive drift.
6. **Shortcuts vs copies**: use a OneLake shortcut for read-only reuse of data
   another team owns; copy when the pipeline needs its own retention, schema
   control, or performance isolation. Never write through a shortcut into
   another owner's storage.
7. **Maintenance** (MUST when production-deployed): scheduled `OPTIMIZE`
   (with V-Order left at the workspace default unless the SDD overrides it) and
   `VACUUM` within the retention the SDD sets; never below the 7-day default without
   a recorded exception.
8. **Partitioning** only on low-cardinality columns queried by filter (typically
   a date). Do not partition small tables; prefer many-file compaction via
   `OPTIMIZE`.
9. The Lakehouse SQL analytics endpoint is **read-only**; hand-editing sink
   tables is prohibited (project policy — schema and data are pipeline-managed).

## Data Pipelines (Data Factory in Fabric)

1. **Parameterize** every environment- or run-varying value (source path, table,
   watermark window, layer). No literals for connection ids, workspace ids,
   item ids or endpoints inside activity definitions.
2. **Connections** are created and owned in Fabric's connection manager (or via
   the deployment process) and referenced by name/parameter; credentials MUST NOT
   appear in pipeline JSON, parameters, or Git.
3. Naming: `pl_<domain>_<purpose>` for pipelines, `nb_<layer>_<entity>` for
   notebooks, `df_<...>` for Dataflows, `lh_<domain>` for Lakehouses,
   `wh_<domain>` for Warehouses. Activity names are verbs: `Copy_<src>_to_bronze`.
4. **Retries**: set explicit retry count/interval on activities that touch
   external systems; never retry a non-idempotent step. Timeouts MUST be set
   (do not leave the default 12-hour timeout on short activities).
5. **Failure is visible**: a failed dependency MUST fail the pipeline or take an
   explicit failure path that notifies (Teams/email/Web activity to the alert
   channel). "Upon completion" paths that swallow failures are prohibited.
6. **Orchestrator/worker split**: a parent pipeline sequences child pipelines
   via *Invoke pipeline*; ForEach fan-out MUST set a bounded `batchCount`.
7. **Incremental loads** persist the watermark in a control table or Delta
   table written **after** the data commit succeeds (see
   `SINK_CONNECTOR_STANDARDS.md` Sink Contract item 4). The watermark MUST NOT
   advance on failure.
8. **Triggers**: schedules are declared in source control (or the release
   script), not created ad hoc in prod. Every scheduled pipeline names an owner
   and an expected duration.
9. Logic that needs unit testing or reuse belongs in a notebook, not in a chain
   of expression-heavy activities.

## Notebooks

1. First code cell is a **parameters cell** (tagged as parameter cell) holding
   defaults; the pipeline overrides them. No environment names hardcoded.
2. Reusable logic lives in a shared module (Fabric Environment library, `%run`
   module notebook, or a wheel) and is unit-testable outside Fabric; the
   notebook itself is thin orchestration over that module.
3. **Secrets** only via Key Vault (`notebookutils.credentials.getSecret`) or a
   workspace identity / managed connection. Never in cells, parameters, or output.
4. **No source/reference data in outputs**: do not `display()`, `show()`, print
   or `.collect()` rows of sensitive data. Log counts and identifiers only.
   Clear cell outputs before commit (or rely on the Fabric Git format that omits them).
5. No unbounded `.collect()`/`.toPandas()` on large tables; stay in Spark
   until the result is small.
6. Notebooks called from pipelines MUST return a structured exit value
   (`notebookutils.notebook.exit(json)`) carrying status, row counts, and the
   run id, and MUST raise on failure rather than exit "successfully".
7. Pin the runtime (Fabric Runtime version) and library versions in the
   Environment item; runtime upgrades are a tracked change with a test run.
8. Spark settings are set per Environment/session with a recorded reason;
   no cargo-cult tuning.

## Dataflows Gen2

1. Use only when Item Selection says so; keep query folding intact for
   database sources and document where folding is broken.
2. Parameterize sources and destinations; set the destination and
   update method (append/replace) explicitly.
3. Complex logic that outgrows Power Query moves to a notebook.

## Security

1. Authentication to Azure resources from Fabric items uses workspace identity,
   managed identity or a service principal held in Key Vault — no shared
   passwords or personal tokens (`SECURITY_AND_PII_STANDARDS.md`).
2. Apply **sensitivity labels** and OneLake/Lakehouse security (item
   permissions, OneLake data access roles, SQL endpoint RLS/CLS) per the
   data contract; do not rely on obscurity of workspace names.
3. Restrict who may run or edit prod items; separate the Git/PR approver
   from the release executor for prod (MUST when production-deployed).
4. Never export, download or log source/reference data outside the configured
   sink; capacity/monitoring exports carry metadata only.

## Configuration

1. Environment-specific values live in **variable libraries** or deployment
   rules / release parameter files, keyed by environment, and are validated at
   pipeline start (fail fast on a missing value).
2. A single documented config surface per workstream; no duplicated constants
   across notebooks and pipelines.

## Observability and Operations

1. Every run carries a **run context**: `run_id`, pipeline/notebook name,
   workstream id, environment, layer, window start/end — written to a control/audit
   table and included in alert payloads (see `OBSERVABILITY_STANDARDS.md`).
2. Row counts in / out / rejected are recorded per stage and reconciled.
3. **Alerting** (MUST when production-deployed): failure, SLA breach (late or
   over-long run), zero-row load on a source that should not be empty, and DQ
   FAIL each route to a named owner channel.
4. Each scheduled pipeline has a **runbook**: symptoms, first checks, safe
   re-run procedure, escalation. Re-run MUST be safe by construction (idempotency above).
5. Track **capacity** health (utilization, throttling, smoothing/carry-forward)
   using the Fabric Capacity Metrics app; sustained throttling is an incident, not a warning.
6. Retain run history beyond the Monitor hub default window via workspace
   monitoring or an exported run-log table when the SDD requires longer audit.

## Deployment and Promotion

1. Path: feature branch → PR (review) → main → dev workspace (Git sync) → test
   → prod via deployment pipeline or scripted release. No direct prod edits.
2. Release automation authenticates as a service principal and is idempotent
   (re-running a release converges, never duplicates items).
3. Environment differences applied at release via deployment rules / parameter
   file / variable library value sets; the release MUST fail if a required
   mapping is missing.
4. Pre-promotion gates: notebook/module unit tests, pipeline validation,
   secret scan, and a smoke run in test against representative data.
5. **Rollback** = redeploy the previous tagged commit; data rollback uses Delta
   time travel (`RESTORE`) within the retention window, and the runbook says
   when each applies.
6. Post-deploy health check: a smoke run succeeds and reconciles counts before
   the release is called done.

## Testing

- Pure logic: unit tests outside Fabric (pytest) on the shared module.
- Pipelines/notebooks: a test-workspace run on a fixed sample dataset asserting
  row counts, schema, idempotency (run twice → identical result) and failure
  path (forced failure → visible alert, watermark unchanged).
- See [TESTING_STANDARDS.md](TESTING_STANDARDS.md) for taxonomy.

## Mandatory Rules

Unconditional:

1. No credentials, tokens, connection strings, workspace/tenant/subscription
   ids or item GUIDs of a real environment committed to Git or logged.
2. No hand-editing of pipeline-managed tables or SQL-endpoint writes to them.
3. No source/reference data (addresses, coordinates, PII) in cell output, logs,
   alert payloads or exports outside the sink.
4. Writes are idempotent for the run window; watermarks advance only after the
   data commit.
5. Failures are visible and never swallowed by a success path.
6. Pipelines and notebooks are parameterized; no environment literals in item logic.

When production-deployed:

7. Git-integrated dev workspace and scripted/pipeline promotion; prod not edited in UI.
8. Service principal / workspace identity for scheduled runs.
9. Failure, SLA and DQ alerting to a named owner, with a runbook.
10. Scheduled Delta maintenance (`OPTIMIZE`, `VACUUM`) with recorded retention.
11. Smoke test and rollback path documented.

## Review Checklist

- [ ] SDD selects Fabric; capacity and workspaces named
- [ ] Right item type chosen per Item Selection
- [ ] Item folders match Git layout; no hand-edited `.platform` ids
- [ ] No literals for connections, ids, environments; parameters/variable library used
- [ ] No secrets or real ids in Git; Key Vault / workspace identity used
- [ ] Medallion layering and naming followed
- [ ] Explicit Delta write mode; idempotent re-run demonstrated
- [ ] Watermark advances only after successful commit
- [ ] Retry/timeout set; failures propagate and alert
- [ ] Notebook returns structured exit value and raises on failure
- [ ] No sensitive data in outputs, logs, alerts
- [ ] Run context/audit table and counts reconciled
- [ ] Promotion path, smoke test, rollback documented (if prod)
- [ ] Maintenance and monitoring/runbook present (if prod)

## Anti-patterns

- Building or editing items directly in the prod workspace.
- Business logic inside pipeline expressions.
- One giant notebook doing extract, transform, DQ and load.
- `overwrite` of a shared Gold table mid-day with no partition scope.
- Pipeline "success" when a child notebook failed.
- Personal-account connections owning scheduled production runs.
- Displaying sample rows of sensitive data "just to debug".
- Environment names or workspace GUIDs pasted into activity settings.

## Notes

Fabric evolves quickly (item formats, variable libraries, workspace monitoring,
CI/CD APIs). Agents MUST verify a feature's current availability and definition
format against current Microsoft documentation before relying on it, and record
any assumption in the SDD.
