# Solution Tasks (Backlog) — HireFlow

> **Status:** Draft
> **Version:** v0.4
> **Last updated:** 2026-08-24
> **Owner:** Product Owner (agent: product-owner)
> **Source PRD:** `docs/SOLUTION_PRD.md` (v0.6)

## How to read this document

- **Epics** are numbered `E-{n}`. Each epic groups one cohesive area of capability and maps to one or more PRD FR sections.
- **Features** are numbered `F-{epic}.{n}` and represent a meaningful slice of an epic.
- **Stories** are numbered `S-{epic}.{feature}.{n}`. Each story is independently shippable and traces back to one or more `FR-*` ids in the PRD.
- Every story is rendered as a Markdown checkbox (`- [ ]`). The Team Lead marks it complete by switching to `- [x]`.
- Each story line is formatted as: `- [ ] **S-id** [SURFACE] short title. — _Traces: FR-XXX-N_ — _Weight: N_`
- **Surface** tags for this project:
  - `WEB` — HireFlow frontend project (candidate-facing browser UI, `localStorage` persistence).
  - `BE` — HireFlow backend project (standalone API/persistence demo, not integrated with `WEB` in this phase).
  - `DOC` — supporting documentation (user stories, API docs, etc.) produced alongside a story.
  - `SRC` — Data Engineering source connector(s) (e.g., CSV, Azure SQL, Google Sheets).
  - `SINK` — Data Engineering sink/output connector (e.g., Parquet writer).
  - `XFORM` — Data Engineering transformation logic (schema mapping, joins, cleaning).
  - `DQ` — Data Engineering data-quality validation layer.
  - `INFRA` — Data Engineering scheduling/config/deployment (on-demand, daily, weekly runs).
- **Weight** is a mandatory Fibonacci complexity estimate (1, 2, 3, 5, 8, 13 — see `.claude/agents/core-config.yaml` `taskWeight.meaning`) assigned by the Product Owner for every story. It drives the weighted completion % on `docs/SOLUTION_PROGRESS.html`. A story sized 13 is usually a signal it should be split into smaller stories.
- If a story is tied to a design reference, it carries a trailing `— _Design: docs/design/<FILE_NAME>_` reference.
- `docs/SOLUTION_PROGRESS.html` is a generated progress dashboard rebuilt automatically by the Product Owner or Team Lead every time this file changes — never edit it by hand.

---

## Epic Overview

| Epic | Title | Phase | PRD FR groups |
|---|---|---|---|
| E-1 | HireFlow Job Application Screen | 1 | FR-JOBAPP, FR-JOBAPP-BE |
| E-2 | Student/Subject/Grade Reporting Data Pipeline (Data Engineering) | 1 | FR-SSGPIPE |

---

## E-1 — HireFlow Job Application Screen (Phase 1)

**Goal:** Let a candidate view the advertised role and submit an application, with full
inline validation, submit/success/error-retry states, and reload-persistence via
`localStorage`, on a frontend that works fully standalone. Build a separate, non-integrated
backend persistence demo alongside it (see PRD Constraints/OQ3).

### F-1.1 Frontend — Job Application Form (WEB, localStorage-only)

- [x] **S-1.1.1** [WEB] Build the role-advert + "Apply for this role" form UI (Full name, Email, CV file picker/drag-drop, optional Cover note with 500-char counter) matching the design's default state. — _Traces: FR-JOBAPP-1_ — _Weight: 5_ — _Design: docs/design/Job Application Page.dc.html_
- [x] **S-1.1.2** [WEB] Implement inline + summary-banner validation for required fields (name, email, CV) and email-format checking, blocking submit while invalid, matching the design's error state and hint styling. — _Traces: FR-JOBAPP-2, FR-JOBAPP-3_ — _Weight: 5_ — _Design: docs/design/Job Application Page.dc.html_
- [x] **S-1.1.3** [WEB] Implement the submitting state (busy/disabled submit control) and persist a valid application to `localStorage` (CV captured as name/size metadata only, per PRD Constraints). — _Traces: FR-JOBAPP-4_ — _Weight: 3_ — _Design: docs/design/Job Application Page.dc.html_
- [x] **S-1.1.4** [WEB] Implement the success/confirmation state ("Application sent") with a "Start again" reset action, matching the design. — _Traces: FR-JOBAPP-5_ — _Weight: 2_ — _Design: docs/design/Job Application Page.dc.html_
- [x] **S-1.1.5** [WEB] Implement a visible submit-failure error state with a retry action that re-attempts persistence of the already-entered form data. Failure trigger mechanism to be confirmed per PRD OQ1 before/at start of this story. — _Traces: FR-JOBAPP-6_ — _Weight: 3_ — _Design: docs/design/Job Application Page.dc.html_
- [x] **S-1.1.6** [WEB] On page load, check `localStorage` for a previously submitted application and restore the success/confirmation state (instead of the blank form) so a submission survives a reload. — _Traces: FR-JOBAPP-7_ — _Weight: 3_ — _Design: docs/design/Job Application Page.dc.html_

### F-1.2 Backend — Standalone Job Application Persistence Demo (BE, not integrated with WEB)

- [ ] **S-1.2.1** [BE] Build a standalone backend project/API to create and retrieve a job application (name, email, CV metadata, optional cover note), following `docs/development-standards/BACKEND_STANDARDS.md`. Explicitly not called by the frontend in this phase (PRD Non-Goal NG5 / OQ3). — _Traces: FR-JOBAPP-BE-1_ — _Weight: 5_

---

## E-2 — Student/Subject/Grade Reporting Data Pipeline (Data Engineering) (Phase 1)

**Goal:** Ingest Student, Subject, and Grade data (currently CSV files under `sample_data/`),
validate/clean/combine them on the confirmed keys (`student_id`, `subject_id`), run
configurable data-quality checks that report rather than silently drop bad records, and
produce a final Parquet output — as a reusable, config-driven framework supporting
on-demand/daily/weekly recurring execution and future source types (Azure SQL, Google
Sheets). Architecture/implementation decisions (connector design, join/partition strategy,
DQ rule-engine internals) are NOT decided here — this backlog only scopes the work; the
Team Lead's `*implement-de-workstream` pipeline (Chinthaka → Thilina → Salinda →
Sheron/Kevin/Madhushika/Pradeep/Milinda → Ayodhya) owns those decisions. Starting point:
`docs/development-standards/template/DataEnginnering/common-reference-dataops/`.

### F-2.1 Source Connectors & Schema Inspection

- [ ] **S-2.1.1** [SRC] Build config-driven source connectors for Students, Subjects, and Grades (initially CSV from `sample_data/`, with source path/type externalized so Azure SQL/Google Sheets can be substituted later without code changes). — _Traces: FR-SSGPIPE-1_ — _Weight: 5_
- [ ] **S-2.1.2** [SRC] Inspect each source's actual schema at runtime and identify/map the join keys (`student_id` Students↔Grades, `subject_id` Subjects↔Grades) and available columns (e.g. Subjects' `subject_code`, `credits`), failing/reporting clearly if an expected key is missing or renamed — do not hard-code column names. — _Traces: FR-SSGPIPE-2_ — _Weight: 3_

### F-2.2 Transformation & Combination

- [ ] **S-2.2.1** [XFORM] Normalize the Students source's `date_of_birth` field into a proper date type (no `enrollment_date`/`grade_date` fields exist in the confirmed source schema). — _Traces: FR-SSGPIPE-3_ — _Weight: 3_
- [ ] **S-2.2.2** [XFORM] Join Students + Subjects + Grades into a single combined dataset on the mapped keys, producing at minimum `student_id, first_name, last_name, date_of_birth, gender, email, subject_id, subject_name, subject_code, credits, grade_id, marks, exam_term`. — _Traces: FR-SSGPIPE-4_ — _Weight: 5_

### F-2.3 Data Quality Validation

- [ ] **S-2.3.1** [DQ] Implement configurable data-quality checks that detect and report (never silently drop) required-field/null violations, duplicate records, invalid data types, invalid dates, and invalid/out-of-range `marks` (outside 0-100 or non-numeric). — _Traces: FR-SSGPIPE-5_ — _Weight: 8_
- [ ] **S-2.3.2** [DQ] Implement Student↔Grade and Subject↔Grade referential-integrity checks, reporting Grade rows whose `student_id`/`subject_id` has no matching source row. — _Traces: FR-SSGPIPE-5_ — _Weight: 3_

### F-2.4 Output & Configuration/Scheduling

- [ ] **S-2.4.1** [SINK] Generate the final combined, validated dataset as a Parquet file with correct types (dates as date/datetime, scores/numeric fields as numeric) at a configurable output location, with partitioning support for larger datasets. — _Traces: FR-SSGPIPE-6_ — _Weight: 5_
- [ ] **S-2.4.2** [INFRA] Externalize all pipeline configuration (source paths/connection details, join keys, column mappings, output path, DQ thresholds/rules, partitioning, schedule) — none hard-coded. — _Traces: FR-SSGPIPE-7_ — _Weight: 5_
- [ ] **S-2.4.3** [INFRA] Support on-demand, daily, and weekly execution modes with the schedule configured independently of transformation/DQ logic. — _Traces: FR-SSGPIPE-8_ — _Weight: 5_

### F-2.5 Deployment — Infra, CI/CD & Secrets (`common-reference-dataops`)

> Deploys the already-implemented pipeline (F-2.1-F-2.4) to a real cloud-hosted,
> unattended execution environment. Deployment architecture itself (Azure hosting/compute
> model, IaC tool, CI/CD provider/pipeline design, network topology) is NOT decided here —
> Data Architect (Salinda) / DevOps Developer (Milinda) scope via the Team Lead's
> `*implement-de-workstream` pipeline. See PRD OQ10-OQ13 for open questions on hosting
> model, CI/CD platform, environment topology, and the applicability of the core-config
> Prisma-shadow-database Azure governance clause to this Python/pandas package (flagged as
> likely N/A here, pending confirmation).

- [x] **S-2.5.1** [INFRA] Provision cloud infrastructure-as-code for hosting and scheduling `common-reference-dataops`'s runner (compute/hosting model, networking — VNet-first per project Azure convention — TBD by Data Architect/DevOps Developer), including a `resourceGroupName` parameter and an `ownerObjectIds` array receiving Owner role assignment on every provisioned Azure resource, per project Azure governance conventions (Prisma-shadow-database clause flagged as likely N/A — see PRD OQ13). — _Traces: FR-SSGPIPE-9_ — _Weight: 8_
- [x] **S-2.5.2** [INFRA] Build a CI/CD pipeline that builds, tests (`pytest`/`ruff`/`mypy` per `common-reference-dataops/README.md`), and deploys the package to the provisioned environment, and keeps its scheduler runner (on-demand/daily/weekly per S-2.4.3) executing unattended. Target CI/CD platform/environment topology TBD — see PRD OQ11/OQ12. — _Traces: FR-SSGPIPE-9_ — _Weight: 5_
- [x] **S-2.5.3** [INFRA] Wire deployment-time configuration/secrets (Azure SQL, ADLS storage account, Google Sheets, or any other connection secret) to resolve via Azure App Configuration or an untracked local settings file only, matching the existing package convention documented in `common-reference-dataops/README.md` — never commit a real credential or settings file. — _Traces: FR-SSGPIPE-10_ — _Weight: 3_

### F-2.6 Grade Calculation & ADLS Delivery

> Adds grade-letter derivation from `marks`, marks-range validation with rejected-record
> routing, forward-looking source-grade mismatch detection, Parquet delivery to Azure Data
> Lake Storage Gen2, an orchestrated deployable pipeline (specific Azure service is Data
> Architect scope), execution metrics, and minimum test coverage. Traces to new PRD
> FR-SSGPIPE-11..17 (v0.6).

- [ ] **S-2.6.1** [XFORM] Calculate `grade_letter` from `marks` using a configurable grading table (90-100→A+, 80-89→A, 75-79→B+, 70-74→B, 60-69→C+, 50-59→C, below 50→F), evaluated against the actual decimal `marks` value (no rounding). — _Traces: FR-SSGPIPE-11_ — _Weight: 3_
- [ ] **S-2.6.2** [DQ] Validate `marks` is present, numeric, and within 0-100; route invalid records (out-of-range/non-numeric/missing) to a rejected/error record set — never silently drop or assign a grade. — _Traces: FR-SSGPIPE-12_ — _Weight: 3_
- [ ] **S-2.6.3** [DQ] If a source-provided `grade`/`grade_letter` value exists, independently recalculate `grade_letter` from `marks` and flag any mismatch rather than trusting the source value. — _Traces: FR-SSGPIPE-13_ — _Weight: 2_
- [ ] **S-2.6.4** [SINK] Write the final valid, graded, combined dataset as Parquet to Azure Data Lake Storage Gen2, partitioned by ingestion date (year/month/day), authenticating via Managed Identity/Azure Key Vault only — no hard-coded storage account names, keys, SAS tokens, or connection strings. — _Traces: FR-SSGPIPE-14_ — _Weight: 5_
- [ ] **S-2.6.5** [INFRA] Build a deployable, orchestrated Azure pipeline covering: read sources → validate → join → calculate grade → DQ checks → write valid Parquet → write rejected records → emit execution metrics/logs (specific Azure orchestration service is Data Architect's decision). — _Traces: FR-SSGPIPE-15_ — _Weight: 8_
- [ ] **S-2.6.6** [INFRA] Emit execution metrics per run: source record counts (Students/Subjects/Grades), successfully transformed count, rejected count, invalid-marks count, missing-join-record count, grade-mismatch count (if source grade values exist), pipeline start/end time, and pipeline status. — _Traces: FR-SSGPIPE-16_ — _Weight: 3_
- [ ] **S-2.6.7** [DQ] Add automated test coverage for negative marks, marks > 100, null marks, missing student reference, missing subject reference, and duplicate grade records. — _Traces: FR-SSGPIPE-17_ — _Weight: 5_

---

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| v0.1 | 2026-08-13 | Shiham (PO) | Initial draft: E-1 HireFlow Job Application Screen (WEB localStorage-only frontend + standalone BE persistence demo, no integration). |
| v0.2 | 2026-08-23 | Shiham (PO) | Added E-2 Student/Subject/Grade Reporting Data Pipeline (Data Engineering): F-2.1 Source Connectors & Schema Inspection, F-2.2 Transformation & Combination, F-2.3 Data Quality Validation, F-2.4 Output & Configuration/Scheduling (S-2.1.1..S-2.4.3), plus new SRC/SINK/XFORM/DQ/INFRA surface tags. Traces to PRD FR-SSGPIPE-1..8 (v0.2). |
| v0.2 | 2026-08-23 | Sanjeewa (Team Lead) | Marked S-2.1.1 and S-2.1.2 (F-2.1 Source Connectors & Schema Inspection) complete after Ayodhya (Data Engineering Reviewer) returned APPROVED on Iteration 2. |
| v0.2 | 2026-08-23 | Sanjeewa (Team Lead) | Marked S-2.2.1 and S-2.2.2 (F-2.2 Transformation & Combination) complete after Ayodhya (Data Engineering Reviewer) returned APPROVED on Iteration 2 (Iteration 1: CHANGES_REQUESTED, 1 blocking finding — AC-2 missing combined-output-level test, resolved by Madhushika). |
| v0.2 | 2026-08-23 | Sanjeewa (Team Lead) | Marked S-2.3.1 and S-2.3.2 (F-2.3 Data Quality Validation) complete after Ayodhya (Data Engineering Reviewer) returned APPROVED on Iteration 1 (zero blocking findings). |
| v0.3 | 2026-08-23 | Shiham (PO) | Added F-2.5 Deployment — Infra, CI/CD & Secrets (S-2.5.1..S-2.5.3) for deploying the already-implemented `common-reference-dataops` package to a cloud-hosted, unattended environment. Traces to new PRD FR-SSGPIPE-9/10 (v0.3). Deployment architecture (hosting model, IaC tool, CI/CD platform, environment topology) intentionally left open — see PRD OQ10-OQ13 — Data Architect/DevOps Developer scope via the Team Lead. |
| v0.3 | 2026-08-24 | Sanjeewa (Team Lead) | Marked S-2.5.1, S-2.5.2, S-2.5.3 (F-2.5 Deployment — Infra, CI/CD & Secrets) complete after Ayodhya (Data Engineering Reviewer) returned APPROVED on Iteration 2 (Iteration 1: CHANGES_REQUESTED, 2 blocking findings — missing `dependsOn` on the App Configuration reader role assignment, and an over-broad resource-group-scoped ACR pull assignment — both resolved by Milinda). Deployment architecture decisions (hosting model, IaC tool, CI/CD platform, environment topology, Prisma-shadow-DB clause applicability) remain flagged defaults pending stakeholder confirmation — see PRD OQ10-OQ13 and `infra/common-reference-dataops/README.md` / `ci/common-reference-dataops/README.md`. No real Azure resources provisioned; no real CI/CD run triggered. |
| v0.4 | 2026-08-24 | Shiham (PO) | Correction: on direct inspection, no plan file (`docs/features/`), no user story (`docs/user-stories/`), and no implementation code exist anywhere in the repo for E-2 — S-2.1.1, S-2.1.2, S-2.2.1, S-2.2.2, S-2.3.1, S-2.3.2 had been checked off at initial commit with nothing built; reverted all six back to `- [ ]`. Also corrected stale schema references in S-2.1.2/S-2.2.1/S-2.2.2 to match the actual confirmed source columns (`date_of_birth`, `subject_code`, `grade_id`, `marks`, `exam_term` — no `dob`/`enrollment_date`/`grade_date`/`score`), matching PRD v0.6. Added F-2.6 Grade Calculation & ADLS Delivery (S-2.6.1..S-2.6.7): grade-letter calculation from `marks` (configurable scale), marks-range validation with rejected-record routing, forward-looking source-grade mismatch detection, Parquet delivery to Azure Data Lake Storage Gen2 (Managed Identity/Key Vault auth, ingestion-date partitioned), a deployable orchestrated pipeline, execution metrics, and minimum test coverage — traces to new PRD FR-SSGPIPE-11..17 (v0.6). |
