# Data Engineering Requirements 2 — Student/Subject/Grade Reporting Data Pipeline

- **Workstream:** E-2 — Student/Subject/Grade Reporting Data Pipeline (Data Engineering)
- **Traces to PRD:** FR-SSGPIPE-1 .. FR-SSGPIPE-17 (`docs/SOLUTION_PRD.md` §11, v0.6)
- **Traces to Task(s):** S-2.1.1, S-2.1.2 (F-2.1); S-2.2.1, S-2.2.2 (F-2.2); S-2.3.1, S-2.3.2 (F-2.3); S-2.4.1, S-2.4.2, S-2.4.3 (F-2.4); S-2.5.1, S-2.5.2, S-2.5.3 (F-2.5); S-2.6.1 .. S-2.6.7 (F-2.6) (`docs/SOLUTION_TASKS.md`, v0.4)
- **Status:** Ready
- **Author:** Chinthaka (Data Engineering PM)
- **Created:** 2026-08-25

## 1. Source

| Topic | Answer |
|---|---|
| Source system(s) | Three flat files: `sample_data/students.csv`, `sample_data/subjects.csv`, `sample_data/grades.csv` (confirmed, directly inspected — see PRD §11.7). No live system-of-record exists today; these are sample/demo files checked into the repo. |
| Source type | File (CSV) today. Requirement (FR-SSGPIPE-1) is that source type/location is configuration-driven so Azure SQL (relational DB) and Google Sheets (SaaS) can be substituted later without touching transformation/DQ code — consistent with the existing `common-reference-dataops` source-connector pattern (Azure SQL + Google Sheets connectors already exist in that template for other domains). |
| Source owner | No external team/system-of-record owns these files today — they are project-local sample data. Production source ownership (e.g. a real Student/Subject/Grade system) is unknown — see OQ6 (PRD, unresolved, non-blocking). |
| Source access method | Local filesystem read (relative path `sample_data/*.csv`) for the current delivery. Future Azure SQL / Google Sheets access methods are out of scope for this delivery — only the config seam to add them later is required now (FR-SSGPIPE-1). |
| Authentication constraints | None for the current CSV files (no credentials involved — plain local files). Any future Azure SQL / Google Sheets connector added under this framework must resolve its own credentials per FR-SSGPIPE-10 (Azure App Configuration or an untracked local settings file) — not applicable to the CSV path itself. |
| Schema availability | Confirmed and stable today (see PRD §11.7): Students = `student_id, first_name, last_name, date_of_birth, gender, email`; Subjects = `subject_id, subject_name, subject_code, credits`; Grades = `grade_id, student_id, subject_id, marks, exam_term`. However, FR-SSGPIPE-2 requires the pipeline to inspect each source's actual schema at runtime rather than hard-coding these column names — treat "known" as "known today, but must not be assumed present without verification," because a future Azure SQL/Google Sheets substitution could rename or reorder columns. |
| Schema stability | Fixed for the current CSV files; no versioning/change process exists for them (they are static sample data). No `grade_letter`/`grade` column exists in any current source — that is derived, not sourced (FR-SSGPIPE-11..13). Future source substitutions may have different schemas; runtime schema inspection (FR-SSGPIPE-2) is the compensating control, not a data-contract negotiation with an external owner. |
| Source-specific limitations | None known for the current CSV files (no rate limits, export windows, or read-replica constraints — plain static files). Not applicable beyond that for this delivery. |

## 2. Volume and Scale

| Topic | Answer |
|---|---|
| Current data volume | Confirmed (PRD §11.7): 5 Students, 5 Subjects, 15 Grades — a trivially small sample dataset, all three files well under 1KB-scale each. |
| Expected growth | Not specified by the business for the CSV sample data itself. However, PRD explicitly requires (G8, NFR "Scalability") that the pipeline be designed to scale beyond this sample size and avoid unnecessary full in-memory loads — i.e., the *framework* must not assume "always 15 rows" even though today's actual data does. Numeric growth targets are unknown — see OQ6/OQ7 (already logged in PRD, non-blocking; left to Data Architect). |
| Record counts | Students: 5. Subjects: 5. Grades: 15 (joins 1:1 to Students/Subjects, so the combined output is expected to be ~15 rows at current volume). |
| File sizes (if file-based) | Sub-kilobyte for all three current files. Not a meaningful sizing constraint at this delivery's actual data. |
| Throughput | Not applicable at current volume — batch read of three small files per run; no throughput target has been specified because none is needed at this scale. |
| Frequency | Per FR-SSGPIPE-8: on-demand, daily, or weekly — configured independently of the transform/DQ logic (see §3 and §5). |
| Concurrency | Not applicable — single-run, single-pipeline-instance execution is assumed; no concurrent-run/multi-tenant requirement has been raised. If concurrent runs of the same pipeline become a requirement later, that is a new business requirement, not an assumption to make here. |

## 3. Processing Model

- **Batch (scheduled/on-demand), not streaming.** PRD explicitly rules out streaming/real-time as a Non-Goal (NG8) — this is a batch/recurring pipeline supporting three execution modes: on-demand, daily, weekly (FR-SSGPIPE-8).
- Rationale: Source data (CSV today; Azure SQL/Google Sheets later) is not event-driven or continuously changing at a rate that justifies streaming; the business need is a periodically refreshed, validated, graded dataset — a classic batch ETL/ELT shape. The current record volume (15 Grade rows) reinforces that batch is appropriate today, but the framework must not be built in a way that only works at this volume (see §12 Proportionality).

## 4. Loading Strategy

| Topic | Answer |
|---|---|
| Full load / incremental / CDC / snapshot | **Full load / full snapshot per run.** Nothing in the PRD or task backlog describes an incremental/watermark/CDC requirement for Students, Subjects, or Grades — every run is expected to (re-)read the full current state of all three sources, combine, validate, grade, and write a fresh output partitioned by ingestion date (FR-SSGPIPE-14). |
| Watermark / cursor / sequence-offset basis | Not applicable — no incremental loading requirement exists in the PRD. If a future source (e.g. Azure SQL with high row counts) makes full-reload infeasible, that would be a new business requirement to raise with the Product Owner (Shiham), not something to assume into scope now. |
| Historical load required? | Not applicable in the traditional "backfill years of history" sense — there is no historical data to backfill beyond the current CSV snapshot. Each scheduled/on-demand run produces a new ingestion-date-partitioned output (FR-SSGPIPE-14), so "history" accumulates naturally as a sequence of full-snapshot runs, not as a one-time historical backfill exercise. |

## 5. Time

| Topic | Answer |
|---|---|
| Frequency | On-demand, daily, or weekly — the specific cadence/time is pipeline configuration, not a hard business rule to fix here (FR-SSGPIPE-8, NG11). Exact daily/weekly time-of-day and timezone is unresolved — PRD OQ8 (non-blocking, left to Data Architect/Operator to set as config default). |
| Freshness requirement | No numeric freshness SLA has been specified beyond "recurring — daily/weekly/on-demand." No stakeholder has asked for e.g. "data must be no more than 24h stale" as a hard constraint. |
| SLA / SLO | This workload IS moving toward production deployment (Azure Container Apps Jobs, Azure DevOps CI/CD, ADLS Gen2 delivery — PRD OQ10-OQ12 resolved), so unlike a pure local demo, some minimal production expectation applies. However, no numeric SLA/SLO (e.g. "99% of runs complete within X minutes," "alert if a scheduled run doesn't fire within Y hours of its window") has been given by the stakeholder. Recommend this be raised to the Product Owner if operational monitoring/alerting commitments are needed beyond the execution metrics already mandated by FR-SSGPIPE-16 — logged as OQ-DE1 below (non-blocking; FR-SSGPIPE-16's metrics are sufficient to proceed without it). |
| Latency | Not applicable — batch job; no sub-run latency requirement exists. |
| Timezone | Not specified — part of PRD OQ8 (non-blocking). Recommend the Data Architect default to a single stated timezone (e.g., UTC) for the schedule config, consistent with FR-SSGPIPE-7's requirement that the schedule be externalized/configurable. |
| Late-arriving data expectations | Not applicable — this is a full-snapshot-per-run load (§4), not an incremental/watermark model, so there is no "late-arriving record relative to a watermark" concept in scope. Any row present in the source files at run time is included in that run. |

## 6. Recovery

| Topic | Answer |
|---|---|
| Restart expectations | A failed run must be safely re-runnable without producing duplicate or corrupted output — each run's output is a distinct ingestion-date partition (FR-SSGPIPE-14), so re-running the same day should overwrite/replace that day's partition rather than append duplicate data. This "re-run same day = clean replacement, not duplication" expectation is inferred from FR-SSGPIPE-14 (partition-by-ingestion-date) and FR-SSGPIPE-15 (deployable orchestrated pipeline with emitted metrics/logs); the exact overwrite/idempotency mechanism is Data Architect scope, not decided here. **Clarification (added 2026-08-25):** this expectation explicitly includes the failure case, not just the happy path — a crash or interruption partway through writing a replacement partition must never leave that partition in a *worse* state than before the write started (e.g., the prior day's valid partition deleted/missing with nothing valid in its place). "Safely re-runnable" means the destination is always either the previous complete partition or the new complete partition, never neither. The specific atomic-replace mechanism (rename semantics, staging pattern, manifest-pointer swap, etc.) remains Data Architect scope. |
| Replay expectations | An operator must be able to re-trigger a given run on-demand (FR-SSGPIPE-8's on-demand mode already covers this) — e.g. to replay a run after fixing an upstream source issue. No requirement exists for replaying a specific historical ingestion-date partition independently of triggering a fresh on-demand run. |
| Backfill requirements | Not applicable in the traditional sense (see §4) — there is no historical backlog to backfill. If a scheduled run is missed (e.g. infrastructure outage), the framework should be re-triggerable on-demand for that day, but no automatic gap-detection/backfill-scheduling requirement has been specified — flagging this as a non-blocking gap for the Data Architect to size appropriately (proportionate to a small daily/weekly job, not a multi-day backfill orchestration system). |
| Failure tolerance | Per FR-SSGPIPE-5/FR-SSGPIPE-12/NG6: the pipeline must never silently drop or "fix" bad records — every DQ violation (nulls, duplicates, invalid types/dates, out-of-range/non-numeric `marks`, referential-integrity breaks) must be detected, routed to a rejected/error record set, and reported, while valid records still proceed through to the graded Parquet output. This is a **partial-failure-tolerant, record-level** failure model, not a whole-run abort-on-first-error model — nothing in the PRD asks for the entire run to fail just because some records are invalid. Whether an entire run should ever hard-fail (e.g., if 100% of Grade rows are invalid, or a required source file is missing) vs. always producing a partial valid + rejected output is unresolved — see PRD OQ5 (non-blocking; recommend the Data Architect propose a sensible default threshold policy, since "configurable rules" was specified but no default was given). |
| Recovery point expectations | Each completed run's Parquet output (partitioned by ingestion date) is the recovery point — there is no in-run checkpoint/resume-mid-run requirement given the current small volume and full-snapshot load model. If volume grows enough that a single run becomes long-running, that would be a new question for the Data Architect at design time, not a requirement to invent here. |

## 7. Destination

| Topic | Answer |
|---|---|
| Expected output / destination | Parquet file(s), written to a configurable output location (FR-SSGPIPE-6/FR-SSGPIPE-7 for the base pipeline), specifically **Azure Data Lake Storage Gen2**, partitioned by ingestion date (year/month/day), per FR-SSGPIPE-14. Rejected/error records must also be written out as a distinct record set (FR-SSGPIPE-12, FR-SSGPIPE-15) — exact rejected-record output format/location is Data Architect scope, but the requirement that it exist and be separate from the valid dataset is a hard business requirement (never silently drop). |
| Downstream consumers | Not yet identified — PRD OQ4 (unresolved, non-blocking; left as an open question for the Product Owner/stakeholder, does not block the current architecture/build since the interim requirement is simply "a well-typed Parquet dataset in ADLS Gen2," which is consumer-agnostic). |
| Consumption pattern | Not specified beyond "a downstream consumer reads the Parquet output from ADLS Gen2" (batch-read pattern, consistent with a partitioned Parquet lake output). No specific BI tool, warehouse load, or API consumption pattern has been named. |
| Overwrite / append / upsert expectation | At the requirement level: each run's output is scoped to that run's ingestion-date partition. Whether re-running within the same ingestion date **overwrites** that day's partition or **appends** an additional file within it is not specified by the business and is left to the Data Architect's design (bounded by the "no duplicate/corrupted output on re-run" recovery expectation in §6). |

## 8. Data Quality

| Topic | Answer |
|---|---|
| Critical fields | Join keys (`student_id`, `subject_id`) — required for referential integrity (FR-SSGPIPE-5); `marks` — required, numeric, 0-100 range, feeds grade-letter derivation (FR-SSGPIPE-11/12); `date_of_birth` — required proper date type (FR-SSGPIPE-3); all "required fields" per each source's confirmed schema (FR-SSGPIPE-5's "required fields/null values" check applies across Students, Subjects, and Grades generically, not just to `marks`). |
| Completeness expectations | No nulls in required fields is the target validation rule (FR-SSGPIPE-5), enforced generically even though the current sample data happens to have zero nulls (PRD §11.7 explicitly flags that production data may not be this clean — the DQ layer must handle nulls even though none exist in the sample). |
| Uniqueness expectations | Duplicate-record detection is a required DQ check (FR-SSGPIPE-5) and explicitly required test coverage (FR-SSGPIPE-17 — "duplicate Grade records"). Exact duplicate-detection key (e.g., full-row duplicate vs. duplicate `grade_id`) is not specified by the business — left to the Data Architect/DQ developer to define per FR-SSGPIPE-7's "DQ thresholds/rules" configuration, but detection itself is mandatory, not optional. |
| Reconciliation needs | Referential-integrity checks act as the reconciliation mechanism here: every Grade row's `student_id` must resolve to a Student row and `subject_id` must resolve to a Subject row (FR-SSGPIPE-5); violations are reported, never silently dropped, and specifically test-covered (FR-SSGPIPE-17 — "no matching Student," "no matching Subject"). No cross-system reconciliation (e.g., against an external source-of-truth record count) has been requested. |
| Business validation expectations | (a) `marks` must be present, numeric, and within 0-100 — invalid rows routed to a rejected/error set, never graded (FR-SSGPIPE-12); (b) `grade_letter` must be derived from `marks` via a configurable scale with exact decimal-boundary semantics (90-100→A+ ... below 50→F, no rounding — FR-SSGPIPE-11); (c) if a source ever supplies its own `grade`/`grade_letter`, the pipeline must independently recalculate and flag any mismatch rather than trust the source value (FR-SSGPIPE-13) — this is forward-looking since no current source has such a column; (d) `date_of_birth` must normalize to a valid date type, tolerating inconsistent input formats generically (FR-SSGPIPE-3); (e) invalid data types generically (FR-SSGPIPE-5). Pass/fail thresholds for when a violation should fail the whole run vs. be a warning-only report line are not specified — PRD OQ5 (non-blocking, already logged). |

## 9. Security

| Topic | Answer |
|---|---|
| PII / sensitive data present? | **Yes.** Student `first_name`, `last_name`, `date_of_birth`, and `email` are personal data. Confirmed explicitly in PRD NFR table ("Student PII ... must be handled per `docs/development-standards/SECURITY_AND_PII_STANDARDS.md`"). No anonymization/masking beyond that standard has been requested. |
| Restricted data categories | Per `SECURITY_AND_PII_STANDARDS.md` rule 11, every field in the eventual data contract carrying Student PII (`first_name`, `last_name`, `date_of_birth`, `email`) must carry an explicit sensitivity classification (at minimum public/internal/confidential/restricted-PII) — this is a Data Architect/data-contract-design responsibility to apply, flagged here as a hard requirement rather than left implicit. `gender` should also be classified (typically internal/confidential depending on org policy) rather than defaulted to unclassified. Grade/academic performance data (`marks`, `grade_letter`) is arguably also sensitive/confidential student-record data (FERPA-adjacent in spirit) even though not literally PII — recommend the Data Architect classify it at minimum "internal/confidential," not "public," pending any explicit stakeholder guidance. |
| Environment constraints | Per `SECURITY_AND_PII_STANDARDS.md` rule 17, production PII must not be copied into dev/test/staging without controls. PRD OQ12 confirms a **single environment topology** (no dev/staging/prod split) for this workstream — meaning there is only one environment, so the classic "don't copy prod PII into a lower environment" scenario does not arise the way it would in a multi-environment topology; however, the current CSV sample data is not real production PII (it is demo/sample data) and must not be treated as if it were, to avoid a false sense that real-PII handling has already been validated. |
| Access requirements | ADLS Gen2 destination access (FR-SSGPIPE-14) must use **Managed Identity and/or Azure Key Vault-resolved credentials only** — no hard-coded storage account names, access keys, SAS tokens, or connection strings (FR-SSGPIPE-14, NFR Security). All other deployment-time secrets (Azure SQL, Google Sheets, or any future connector credential) must resolve via Azure App Configuration or an untracked local settings file (FR-SSGPIPE-10) — never committed to source control, matching the existing `common-reference-dataops/README.md` convention. |
| Retention / deletion expectations | Not specified by the business for this workload — no retention period or deletion trigger has been given for the ADLS Gen2 output or the rejected-record set. Given the workload is genuinely production-bound (Container Apps Jobs, real ADLS Gen2 storage), this is a real gap, not a proportionality non-issue — logged as OQ-DE2 below (non-blocking for architecture start, but should be resolved before the storage account's lifecycle policy is finalized). |

## 10. Governance

| Topic | Answer |
|---|---|
| Ownership | Not formally named — the PRD identifies a "Data Engineer / Pipeline Operator" persona who configures/runs/troubleshoots the pipeline, but no named team/system owns the Student/Subject/Grade data itself going forward (the CSVs are project-local sample data, not an owned system-of-record). Not blocking for this delivery since the current source is sample data; would need resolution before a real production source (Azure SQL, etc.) replaces it — ties to OQ6. |
| Downstream dependencies | Unknown — see §7 (Downstream consumers) and PRD OQ4. No consumer has registered a dependency on this pipeline's output yet. |
| Lineage expectations | No formal lineage tooling/requirement has been requested (PRD explicitly rules out building a monitoring dashboard/UI as a Non-Goal, NG9). The minimum "inspectable" lineage signal required is the execution metrics mandated by FR-SSGPIPE-16 (source counts, transformed count, rejected count, invalid-marks count, missing-join-record count, grade-mismatch count, start/end time, status) plus logs/metrics emitted per FR-SSGPIPE-15 — this is sufficient traceability for the current scope; a dedicated lineage/catalog system is not warranted at this scale (see §12). |
| Contract expectations | A formal, versioned data contract (per `DATA_CONTRACT_STANDARDS.md`) is warranted here because: (a) the output is now delivered to a real cloud destination (ADLS Gen2) intended for downstream consumption, (b) the schema includes PII and semi-sensitive fields requiring explicit sensitivity classification (§9), and (c) FR-SSGPIPE-13's forward-looking mismatch-detection logic implies the schema may evolve (a source someday adding its own `grade`/`grade_letter` column). Recommend the Data Architect define a minimum data contract for the combined/graded output schema (field names, types, sensitivity classification, nullability) rather than treating this as a throwaway script's ad hoc schema. |

## 11. Open Questions

> Anything unresolved goes here — never silently assumed. If any item here is
> critical to starting architecture, set Status=Blocked. None of the items below are
> blocking — the PRD's own critical deployment-architecture questions (former OQ10-OQ13)
> are already resolved (Container Apps Jobs, Azure DevOps Pipelines, single environment,
> Prisma-shadow-DB clause N/A). The remaining PRD-level open questions (OQ4, OQ5, OQ6,
> OQ7, OQ8, OQ9) and the two DE-specific gaps below are all non-critical detail-level
> questions appropriate for the Data Architect to default sensibly and flag, not blockers
> to starting the SDD.

- OQ4 (PRD) — Who is the downstream consumer of the final Parquet output? — Blocking: N — routed to: Shiham (business), via Team Lead if/when a concrete consumer needs to be onboarded.
- OQ5 (PRD) — What DQ threshold/tolerance policy determines a run-level pass/fail vs. a warning-only report? — Blocking: N — routed to: Data Architect (Salinda) to propose a sensible default (e.g., "no violation ever fails the whole run; all violations are routed to the rejected set and reported"), pending stakeholder confirmation via Shiham if a stricter policy is later requested.
- OQ6 (PRD) — What are the target production source locations (real Azure SQL tables, a specific Google Sheet) if/when this moves beyond the CSV sample? — Blocking: N — routed to: user/stakeholder, not needed to start this delivery (current scope explicitly targets the CSV sample data).
- OQ7 (PRD) — Default output path/location and partitioning scheme beyond "partition by ingestion date" (already fixed by FR-SSGPIPE-14)? — Blocking: N — routed to: Data Architect (Salinda), config-driven per FR-SSGPIPE-7.
- OQ8 (PRD) — Exact daily/weekly schedule time/timezone, and the on-demand trigger mechanism (CLI, orchestrator, API)? — Blocking: N — routed to: Data Architect (Salinda) to set a sensible config default (recommend UTC).
- OQ9 (PRD) — Where/how should the DQ report be delivered (log, file, table, alert)? — Blocking: N — routed to: Data Architect (Salinda); minimum floor is already set by FR-SSGPIPE-16's mandatory execution metrics.
- OQ-DE1 (new) — Is a numeric SLA/SLO (e.g., run-completion time bound, missed-schedule alerting) required now that this pipeline targets a real Container Apps Jobs deployment, or are the FR-SSGPIPE-16 execution metrics sufficient for this phase? — Blocking: N — routed to: Shiham (Product Owner), only if formal operational monitoring commitments are wanted; FR-SSGPIPE-16 is sufficient to proceed without an answer.
- OQ-DE2 (new) — What retention/deletion policy applies to the ADLS Gen2 output (valid Parquet dataset and rejected-record set) and how long should PII-bearing records be retained? — Blocking: N for starting architecture, but should be resolved before the storage account's lifecycle/retention policy is finalized in the SDD/infra work — routed to: Shiham (Product Owner) for the business retention rule, then Data Architect (Salinda) to implement it.

## 12. Proportionality Assessment

This workload sits at a real inflection point, not a uniformly simple or uniformly enterprise
case, and the DE Requirements above are sized accordingly. The **current actual data**
(5 Students, 5 Subjects, 15 Grades, static CSV files, no incremental/CDC need, no SLA) is
trivially small and would, on its own, justify a lightweight, single-environment, no-lineage,
no-formal-contract build. However, three concrete signals push several controls into "must
apply now, not later": (1) FR-SSGPIPE-1/G8/G10 explicitly require the source layer be
config-driven for Azure SQL/Google Sheets substitution — so source-abstraction discipline is
mandatory today even though only one source type exists today; (2) FR-SSGPIPE-9/10/14 and the
already-resolved OQ10-OQ13 commit this workload to a *real* cloud deployment (Azure Container
Apps Jobs, Azure DevOps CI/CD, ADLS Gen2, Managed Identity/Key Vault) — so security/secrets
handling, deployability, and execution-metrics observability (FR-SSGPIPE-16) are production-grade
requirements now, not deferred "later" concerns; (3) the presence of Student PII plus
grade/academic data pushes formal sensitivity classification and a minimum data contract into
scope (§9/§10) despite the small row count, because classification obligations trigger on *data
sensitivity*, not on volume. Conversely, multi-environment topology, formal lineage tooling, a
monitoring dashboard/UI, incremental/CDC loading, and numeric SLA/SLO enforcement are explicitly
NOT warranted at this stage — PRD Non-Goals (NG8, NG9) and the resolved OQ12 (single environment)
rule those out directly, and nothing in the current scope needs them. In short: build the
framework abstraction and security/deployment rigor at production-grade discipline now, but do
not over-build monitoring/lineage/multi-environment infrastructure the business has not asked
for and has explicitly scoped out.

## 13. Handoff

- **Business Analyst (Thilina):** consumes this document as context for the user
  story. The story itself remains business-readable — DE detail from this document
  MUST NOT leak into Acceptance Criteria wording.
- **Data Architect (Salinda):** consumes this document as the primary input to the
  SDD, alongside the PRD (`docs/SOLUTION_PRD.md` §11, v0.6) and task backlog
  (`docs/SOLUTION_TASKS.md` E-2, v0.4). Note in particular: §4 (full-load, no
  incremental strategy needed), §6 (partition-level idempotent re-run expectation,
  exact mechanism left to you), §9 (mandatory sensitivity classification and
  Managed Identity/Key Vault-only ADLS access), and §10 (a minimum data contract is
  warranted for the combined/graded output schema).

## Change Log

| Date | Author | Change |
|---|---|---|
| 2026-08-25 | Chinthaka (DE PM) | Initial draft covering the full FR-SSGPIPE-1..17 requirement set (source ingestion/schema inspection F-2.1, transformation/join F-2.2, DQ validation F-2.3, output/config/scheduling F-2.4, deployment F-2.5, and grade calculation & ADLS delivery F-2.6). Status=Ready — no critical blocking DE questions; all open items are non-blocking and routed per §11. |
| 2026-08-25 | Chinthaka (DE PM) | Re-entry review after Ayodhya's iteration-1 CHANGES_REQUESTED (`docs/features/2.1_STUDENT_SUBJECT_GRADE_PIPELINE_DE_REVIEW.md`). Confirmed with Shiham (Product Owner) that none of the 5 findings are requirements-level gaps — all are DE Plan specialist-dispatch coverage gaps or code defects. Made one minor clarifying addition to §6 "Restart expectations" making explicit that the recovery expectation covers the failure case (a mid-write crash must never leave the destination in a worse/absent state than before), since this was only implicit before and directly relates to Blocking Finding #3 (sink atomicity defect). No other section changed. Status remains Ready. |
