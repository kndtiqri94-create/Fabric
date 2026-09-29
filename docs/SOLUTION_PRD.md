# Product Requirements Document — HireFlow

> **Status:** Draft
> **Version:** v0.6
> **Last updated:** 2026-08-24
> **Owner:** Product Owner (agent: product-owner)

## 1. Vision
HireFlow is a recruitment platform. This first slice covers the candidate-facing Job
Application screen for an advertised role: a candidate reads a role advert and submits an
application (name, email, CV, optional cover note). This is a demo project: the goal is to
demonstrate the end-to-end screen behaviour (validation, submit, success, error/retry,
reload-persistence) rather than a production-integrated hiring pipeline.

## 2. Goals & Non-Goals
### 2.1 Goals
- G1 Let a candidate view an advertised role and submit a complete application in under 2 minutes.
- G2 Validate required fields and email format client-side before allowing submit, with inline errors.
- G3 Persist a submitted application so it survives a page reload.
- G4 Handle every state shown in the design: default, validating, submitting, success, error (with retry).
- G5 Deliver both a backend project and a frontend project for this feature as separate demo artifacts (see Constraints — they are intentionally not integrated for this phase).

### 2.2 Non-Goals (explicit)
- NG1 Authentication / candidate accounts.
- NG2 Multi-step application wizard (this is a single-page/single-step form).
- NG3 Server-side email notifications to the candidate or hiring manager.
- NG4 Job search / role listing / browse experience (the "All open roles" link and other-roles browsing are out of scope; only the single advertised-role application screen is in scope).
- NG5 Frontend↔backend integration — for this demo phase the frontend does not call the backend API (see Constraints).

## 3. Primary Users / Personas
- **Candidate** — an external job applicant viewing the advertised role page and submitting their application. No account/login; single anonymous session per browser.

## 4. Key Use Cases
- UC1 — Happy path: candidate opens the role page, fills name/email/CV (+ optional cover note), submits, sees a success/confirmation state, and the application persists (survives reload).
- UC2 — Validation: candidate tries to submit with a missing required field or a malformed email; inline errors appear per field plus a summary banner, and submit stays blocked until fixed.
- UC3 — Submit failure & retry: the persist step fails; the candidate sees a visible error state (not silent) and can retry the same submission without re-entering data.

## 5. Functional Requirements
> Grouped by domain area. Each requirement gets a stable id `FR-<area>-<N>`.

### 5.1 Job Application Form (frontend, FR-JOBAPP)
- **FR-JOBAPP-1** Render the "Apply for this role" form for the single advertised role, matching the fields on the design: Full name (required, text), Email (required, must match a valid email pattern), CV (required, file picker + drag-and-drop, accepts .pdf/.doc/.docx up to 10MB — store file name/size only, not binary content, per the localStorage constraint), Cover note (optional, up to 500 characters, with a live character counter).
- **FR-JOBAPP-2** Validate required fields (name, email, CV) and email format. Do not run validation error display before the candidate has attempted a submit ("tried" state), then re-validate live per the design's behaviour. Block the submit action while any required field is invalid or missing.
- **FR-JOBAPP-3** On invalid submit attempt: show an inline error under each invalid field, show an error summary banner at the top of the form, and set focus/visual highlighting per the design's error styling. Submit must remain blocked until all errors are resolved.
- **FR-JOBAPP-4** On a valid submit: transition the form into a "submitting" state (disable the submit control / show a busy indicator) while the application is persisted, matching the design's default/validating/submitting/success/error state set.
- **FR-JOBAPP-5** On successful persistence: show the "Application sent" success/confirmation state (per design), including a "Start again" action that resets the form to a fresh, empty application.
- **FR-JOBAPP-6** On a persistence failure: show a visible, non-blocking error state (not just a console error) explaining the submit failed, and offer a retry action that re-attempts persistence of the same in-memory form data without forcing the candidate to re-enter it.
- **FR-JOBAPP-7** A successfully submitted application must persist across a full page reload — i.e. after reload, the candidate should see the same submitted/success state for that application rather than a blank form (persisted via `localStorage`, see Constraints).

### 5.2 Job Application Persistence — Backend (demo, standalone) (FR-JOBAPP-BE)
- **FR-JOBAPP-BE-1** Build a standalone backend project that exposes an API to create/persist a job application (name, email, CV metadata, optional cover note) and to retrieve a persisted application, following the repo's backend development standards. This backend is a demo artifact for this phase — see Constraints; it is not called by the frontend.

## 6. Non-Functional Requirements
| Category | Requirement |
|---|---|
| Security | Demo-only: no auth required for this screen (see Non-Goals). No sensitive data handling requirements beyond basic input sanitization of free-text fields. |
| Performance | A candidate can complete and submit the form in under 2 minutes (UX/flow requirement, not a server latency target — no backend is called from the frontend in this phase). |
| Availability | Frontend must work fully standalone (no backend dependency) since it persists to `localStorage`. |
| Accessibility | WCAG 2.1 AA, per `docs/design/CLAUDE.md` project design rules (contrast, mobile-first down to 360px). |
| Compliance | None specified for this demo. |
| Observability | Not required for this demo phase beyond visible in-UI error states. |

## 7. Constraints & Assumptions
- **Demo project only.** Both a backend project and a frontend project must be built for this feature, but they are explicitly **not integrated** in this phase — the frontend does not call the backend API.
- The frontend persists application data using browser **`localStorage`** only, and must work fully independently of any backend/API.
- CV "upload" in the frontend is demo-only: since data is stored in `localStorage`, only the file's name and size are captured/persisted (matching the design's own mock behaviour), not the file's binary contents.
- Design reference: the user referenced `.docs/design/Job Application Page.dc`. The project's actual design docs live under `docs/design/`, and the closest matching file found there is `docs/design/Job Application Page.dc.html`. This PRD treats that file as the intended design reference — **flagging the path/extension mismatch** in case a different or newer file was intended.
- Design source also implies two related design files present in `docs/design/` that are explicitly out of scope for this feature: `Job Application Mobile.dc.html` (mobile variant — not requested, not built under this task) and `Open Roles*.dc.html` (role browse/search — excluded per Non-Goals NG4). Not building against these now; flagged so they aren't accidentally assumed in scope.
- Assumption: "Success/failure" for the frontend persistence step is simulated/demo logic (e.g., a deliberate or injectable failure path) since a `localStorage` write essentially always succeeds outside of quota/availability edge cases (private browsing storage limits, quota exceeded, storage disabled). The exact mechanism for triggering the "submit failure" state is not yet specified by the stakeholder — see Open Questions OQ1.

## 8. Dependencies
- `docs/design/Job Application Page.dc.html` — visual design reference (see path/extension flag above).
- `docs/design/CLAUDE.md` — HireFlow brand/design rules (contrast, mobile-first, component reuse, no gradients/heavy shadows).
- `docs/development-standards/BACKEND_STANDARDS.md`, `docs/development-standards/FRONTEND_STANDARDS.md` — mandatory implementation conventions for both projects.

## 9. Open Questions
- OQ1 — What should trigger the frontend's "submit failure" state in a `localStorage`-only demo (e.g., a simulated random/toggleable failure, an actual `localStorage` quota-exceeded/unavailable condition, or a deliberate "fail once then succeed on retry" demo affordance)? Needs stakeholder confirmation before the Frontend Developer builds the error/retry path. Owner: stakeholder, target resolution: before implementation of FR-JOBAPP-6.
- OQ2 — Confirm the intended design file: is `docs/design/Job Application Page.dc.html` the correct reference for `.docs/design/Job Application Page.dc`, or was a different/newer file meant? Owner: stakeholder.
- OQ3 — Backend persistence (FR-JOBAPP-BE-1) is being built as a standalone, non-integrated demo artifact per explicit instruction. No further backend-specific behavioural requirements (e.g., auth, listing/search for hiring managers) were given — confirm if any are expected in this phase or deferred entirely.

## 11. Feature: Student/Subject/Grade Reporting Data Pipeline (Data Engineering)
> This is a separate product area sharing this same solution PRD/backlog (see
> `.claude/agents/core-config.yaml` — one shared backlog for all workstreams). It is a
> PyTIQ Data Engineering workstream: this PRD captures the business problem, scope,
> constraints and acceptance outcomes only. Incremental/watermark strategy, partitioning,
> connector implementation, join/transform design, storage technology, and DQ rule-engine
> design are explicitly NOT specified here — those belong to the Data Engineering PM
> (Chinthaka) and Data Architect (Salinda), reached via the Team Lead (Sanjeewa).

### 11.1 Vision
Build a reusable, config-driven data pipeline that ingests Student, Subject, and Grade
data, validates and cleans it, combines the three into a single dataset, runs data-quality
checks, and produces a Parquet output. The pipeline must be designed as a recurring,
extensible framework (not a one-off script) so additional sources/transformations and
alternate source types (Azure SQL, Google Sheets) can be added later without rewriting
core logic.

### 11.2 Goals & Non-Goals
#### Goals
- G6 Ingest Student, Subject, and Grade data and produce a single validated, combined dataset in Parquet format.
- G7 Detect and report — never silently drop or auto-fix — data-quality issues: nulls, duplicates, invalid types, invalid dates, invalid/out-of-range scores, and referential-integrity violations between Student↔Grade and Subject↔Grade.
- G8 Build the pipeline as a reusable, config-driven framework with clearly separated components (source connectors, ingestion, schema validation, data cleaning, transformation, data-quality validation, output generation) so new sources/transformations can be added later.
- G9 Support recurring execution: on-demand, daily, and weekly, with the schedule configured separately from the transformation/DQ logic.
- G10 Design for source portability — CSV today, with Azure SQL and Google Sheets as future source types via configuration, consistent with this project's existing reference-data ingestion template/`common-reference-dataops` package.

- G11 Deploy the implemented `common-reference-dataops` pipeline package (source connectors → transform/combine → DQ → Parquet sink → scheduler runner, all already built per F-2.1-F-2.4) to a real cloud-hosted execution environment — provisioned as code, with automated CI/CD, and centrally managed configuration/secrets — so it runs unattended per its configured schedule instead of only from a developer's local machine.
- G12 Derive a letter grade from each Grade record's `marks` using a configurable grading scale, validate `marks` is within range, and deliver the graded, combined dataset to Azure Data Lake Storage Gen2 (Parquet, partitioned by ingestion date) via an orchestrated, deployable pipeline that emits execution metrics and never silently drops or mis-grades invalid records.

#### Non-Goals (explicit)
- NG6 Silently removing or "fixing" invalid, missing, or duplicate records — all such records must be detected and reported per configurable rules instead.
- NG7 Specifying the technical pipeline architecture itself (incremental/CDC strategy, partitioning scheme, connector class design, DQ rule-engine internals, storage/framework choice) — that is Data Architect/DE PM scope, not Product Owner scope.
- NG8 Real-time/streaming ingestion — this is a batch/recurring pipeline (on-demand/daily/weekly), not sub-daily/streaming, unless a future request changes this.
- NG9 Building a monitoring dashboard/UI for pipeline runs or DQ reports — the form/destination of DQ reports and run history is not specified (see Open Questions).
- NG10 Specifying the deployment architecture itself (compute/hosting model, IaC tool, CI/CD provider/pipeline design, network topology) — that is Data Architect/DevOps Developer scope via the Team Lead, not Product Owner scope.
- NG11 Deciding a new schedule cadence/trigger time for the deployed environment — the run mode/cadence is already externalized as pipeline config per FR-SSGPIPE-8; deployment must honor whatever is configured there, not redefine it.
- NG12 Choosing the specific Azure orchestration service (ADF vs. Synapse vs. Databricks vs. Functions, etc.) for FR-SSGPIPE-15 — that is Data Architect (Salinda) scope via the Team Lead; this PRD only requires that a deployable, orchestrated pipeline with the stated stages exists.

### 11.3 Primary Users / Personas
- **Data Engineer / Pipeline Operator** — configures, runs (on-demand or via schedule), and troubleshoots the pipeline; needs clear, actionable DQ reports rather than silent data loss.
- **Downstream data consumer** — consumes the final Parquet output (exact consumer/system not yet identified — see Open Questions OQ4).

### 11.4 Key Use Cases
- UC4 — On-demand run: an operator triggers the pipeline manually against the current CSV sources and receives a validated Parquet output plus a report of any detected data-quality issues (nulls, duplicates, invalid types/dates/scores, referential-integrity breaks).
- UC5 — Scheduled run: the pipeline runs unattended on a configured daily or weekly schedule, producing a fresh Parquet output and DQ report each run without code changes.
- UC6 — Adding a new source later: an engineer points the pipeline at a different source type (e.g., Azure SQL or Google Sheets instead of CSV) via configuration, without modifying the transformation or data-quality logic.

### 11.5 Functional Requirements — Student/Subject/Grade Pipeline (FR-SSGPIPE)
- **FR-SSGPIPE-1** Ingest three sources — Students, Subjects, Grades — currently provided as `sample_data/students.csv`, `sample_data/subjects.csv`, `sample_data/grades.csv`. Source location/type must be configuration-driven (not hard-coded) so it can later point to Azure SQL or a Google Sheet.
- **FR-SSGPIPE-2** Inspect each source's actual schema at runtime rather than assuming column names; verify the expected join keys are present (`student_id` linking Students→Grades; `subject_id` linking Subjects→Grades) and identify/map them from the real schema, failing/reporting clearly if an expected key is missing or renamed.
- **FR-SSGPIPE-3** Normalize the Students source's `date_of_birth` field into a proper date type, handling any inconsistent input date formats generically (no `enrollment_date`/`grade_date` fields exist in the confirmed source schema — see §11.7).
- **FR-SSGPIPE-4** Combine Students + Subjects + Grades into one dataset joined on `student_id` and `subject_id`. At minimum the output must logically contain: `student_id, first_name, last_name, date_of_birth, gender, email, subject_id, subject_name, subject_code, credits, grade_id, marks, exam_term` (per the confirmed actual source schemas in §11.7).
- **FR-SSGPIPE-5** Run configurable data-quality checks and report (never silently drop) violations for: required fields, null values, duplicate records, invalid data types, invalid dates, invalid/out-of-range `marks` (e.g., a value outside 0-100 or a non-numeric value), Student↔Grade referential integrity, and Subject↔Grade referential integrity.
- **FR-SSGPIPE-6** Produce the final dataset as a Parquet file with correct schema/types (dates as date/datetime types, `marks`/numeric fields as numeric types), to a configurable output location, with partitioning support available for larger datasets.
- **FR-SSGPIPE-7** Externalize configuration for: source paths/connection details, join keys, column mappings, output path, data-quality thresholds/rules, partitioning, the run schedule, and (per FR-SSGPIPE-11) the grade-letter scale — none of these hard-coded in code.
- **FR-SSGPIPE-8** Support three execution modes — on-demand, daily, and weekly — with the schedule configured independently of the transformation/DQ logic.
- **FR-SSGPIPE-9** Deploy the implemented `common-reference-dataops` package to a cloud-hosted environment via infrastructure-as-code (exact Azure hosting/compute model not yet decided — see Open Questions), with a CI/CD pipeline that builds, tests (`pytest`/`ruff`/`mypy`), and deploys the package, and keeps its scheduler runner (FR-SSGPIPE-8's on-demand/daily/weekly modes) executing unattended in that environment.
- **FR-SSGPIPE-10** All deployment-time configuration and secrets (Azure SQL connection info, ADLS storage account credentials, Google Sheets credentials, or any other connection secret used by the deployed pipeline) must resolve via Azure App Configuration or an untracked local settings file — never a literal value committed to source control — matching the convention already documented in `common-reference-dataops/README.md`.
- **FR-SSGPIPE-11** Calculate a `grade_letter` for every Grade record from its `marks` value, using a configurable grading scale (not hard-coded branching logic), matching this default table: 90-100 → A+, 80-89 → A, 75-79 → B+, 70-74 → B, 60-69 → C+, 50-59 → C, below 50 → F. Boundaries are evaluated against the actual decimal `marks` value (e.g. 74.99 → B, not rounded to 75 → B+).
- **FR-SSGPIPE-12** Validate `marks` is present, numeric, and within 0-100 before grade calculation. Any record failing this check (out-of-range, non-numeric, or missing `marks`) must be routed to a rejected/error record set via the data-quality layer (extends FR-SSGPIPE-5) — never silently dropped and never assigned a grade letter.
- **FR-SSGPIPE-13** (Forward-looking) If a future source revision provides its own `grade`/`grade_letter` value, the pipeline must still independently calculate `grade_letter` from `marks` per FR-SSGPIPE-11 and flag any mismatch between the source-provided value and the calculated value as a data-quality finding, rather than trusting the source value outright — consistent with the "detect and report, never silently trust" DQ philosophy in FR-SSGPIPE-5.
- **FR-SSGPIPE-14** Write the final valid, graded, combined dataset as Parquet to Azure Data Lake Storage Gen2, partitioned by ingestion date (year/month/day), authenticating via Managed Identity and/or Azure Key Vault-resolved credentials only. Storage account names, access keys, SAS tokens, and connection strings must never be hard-coded — they must be configuration/Key-Vault-driven (extends FR-SSGPIPE-6 and FR-SSGPIPE-10).
- **FR-SSGPIPE-15** Deliver a deployable, orchestrated Azure pipeline covering the stages: read sources → validate → join → calculate grade → run data-quality checks → write valid records to Parquet → write rejected records → emit execution metrics/logs. The specific Azure orchestration service is not prescribed here (see NG12) — that choice belongs to the Data Architect based on the existing project structure.
- **FR-SSGPIPE-16** The pipeline must emit, at minimum, these execution metrics for every run: source record counts (Students, Subjects, Grades), successfully transformed record count, total rejected record count, invalid-`marks` count, missing-join-record count (Student↔Grade / Subject↔Grade), grade-mismatch count (when a source-provided grade value exists per FR-SSGPIPE-13), pipeline start time, pipeline end time, and overall pipeline status.
- **FR-SSGPIPE-17** Automated test coverage for the grade-calculation and marks-validation logic must include, at minimum: negative marks, marks greater than 100, null marks, a Grade record with no matching Student, a Grade record with no matching Subject, and duplicate Grade records.

### 11.6 Non-Functional Requirements
| Category | Requirement |
|---|---|
| Scalability | Pipeline must be designed to scale beyond the current small sample dataset; avoid unnecessary full in-memory loads; joins/transforms should be able to scale to larger volumes (specific execution strategy is Data Architect scope). |
| Reliability | Data-quality violations must always be detected and reported, never silently discarded, per FR-SSGPIPE-5. |
| Extensibility | Adding a new source or transformation must not require rewriting existing ingestion/validation/cleaning/transformation/DQ/output components (component separation per G8). |
| Observability | Each run (especially scheduled ones) must produce an inspectable record of detected DQ issues (exact report format/destination is an Open Question) and must emit the execution metrics required by FR-SSGPIPE-16. |
| Security | Student PII (name, `date_of_birth`, email) must be handled per `docs/development-standards/SECURITY_AND_PII_STANDARDS.md`; no PII masking/anonymization beyond that standard is assumed unless specified later. ADLS Gen2 access (FR-SSGPIPE-14) must use Managed Identity and/or Azure Key Vault-resolved credentials only — no hard-coded storage account names, keys, SAS tokens, or connection strings. |

### 11.7 Constraints & Assumptions
- Current sources are three CSV files at `sample_data/students.csv`, `sample_data/subjects.csv`, `sample_data/grades.csv`. Confirmed actual columns (directly inspected): Students = `student_id, first_name, last_name, date_of_birth, gender, email`; Subjects = `subject_id, subject_name, subject_code, credits`; Grades = `grade_id, student_id, subject_id, marks, exam_term`. There is no `enrollment_date`, `grade_date`, `score`, or existing `grade`/`grade_letter` column in any of the real files — `grade_letter` is entirely derived from `marks` per FR-SSGPIPE-11.
- The current sample data (5 Students, 5 Subjects, 15 Grades) has no nulls, duplicates, or out-of-range values in the sampled rows, but the configurable data-quality layer must still handle nulls, duplicates, invalid types, invalid `date_of_birth` formats, out-of-range/non-numeric `marks`, and Student↔Grade/Subject↔Grade referential-integrity breaks generically, since production data may not be this clean.
- Technical architecture (connector implementation, join/partitioning strategy, storage/framework choices, DQ rule-engine design, incremental/schedule-trigger mechanism) is explicitly out of scope for this PRD — Data Architect (Salinda) / Data Engineering PM (Chinthaka) scope via the Team Lead.
- Assumption: initial delivery targets the CSV files in `sample_data/` as-is; production source locations (e.g., a real Azure SQL Student/Subject/Grade schema) are not yet known (see Open Questions).
- Per this project's Data Engineering conventions, implementation should start from `docs/development-standards/template/DataEnginnering/common-reference-dataops/` as the canonical package template rather than being built from scratch.

### 11.8 Dependencies
- `docs/development-standards/DATA_ENGINEERING_STANDARDS.md`, `SOURCE_CONNECTOR_STANDARDS.md`, `SINK_CONNECTOR_STANDARDS.md`, `TRANSFORMATION_STANDARDS.md`, `DATA_QUALITY_STANDARDS.md`, `DATA_CONTRACT_STANDARDS.md`, `CONFIGURATION_STANDARDS.md`, `PERFORMANCE_AND_SCALE_STANDARDS.md`, `SECURITY_AND_PII_STANDARDS.md`, `DEPLOYMENT_STANDARDS.md` — mandatory conventions for this workstream.
- `docs/development-standards/template/DataEnginnering/common-reference-dataops/` — canonical starting package template/structure.
- `sample_data/Student.csv`, `sample_data/Subject.csv`, `sample_data/Grade.csv` — current source files.
- `docs/development-standards/template/DataEnginnering/common-reference-dataops/README.md` — documents the canonical package structure (F-2.1-F-2.4) and its existing "never commit real credentials/settings" convention that FR-SSGPIPE-10 extends to deployment.

### 11.9 Open Questions
- OQ4 — Who/what is the downstream consumer of the final Parquet output (a BI tool, a data lake/warehouse zone, another pipeline)? Not yet specified.
- OQ5 — What data-quality thresholds/rules should fail a run vs. produce a warning-only report (e.g., does any invalid score fail the whole run, or is there a tolerance %)? User specified "configurable rules" but gave no default policy.
- OQ6 — What are the target production source locations if/when this moves beyond the CSV sample data (e.g., real Azure SQL Student/Subject/Grade tables, a specific Google Sheet)? Not yet known.
- OQ7 — Default output path/location and partitioning scheme (e.g., partition by `grade_date`, by `subject_id`, or none at current small volume)? Not specified — left to the Data Architect, must remain config-driven per FR-SSGPIPE-7.
- OQ8 — Exact daily/weekly schedule time/timezone, and what triggers on-demand runs (CLI, orchestrator, API call)? Not specified.
- OQ9 — Where/how should the DQ report (detected null/duplicate/invalid/referential-integrity findings) be delivered — a log, a separate report file, a table, an alert? Not specified (relates to NG9/Observability).
- ~~OQ10~~ **RESOLVED (2026-08-24)** — What is the target Azure hosting/compute model for running the deployed scheduler runner? **Decision: Azure Container Apps Jobs**, with a scheduled trigger plus manual on-demand execution. Confirmed by stakeholder as the target for future infra work — no `infra/` directory or Bicep module exists in the repo yet; this decision is a requirement for Salinda (Data Architect)/Milinda (DevOps Developer) to implement, not a record of prior implementation.
- ~~OQ11~~ **RESOLVED (2026-08-24)** — What CI/CD platform should build/test/deploy this package? **Decision: Azure DevOps Pipelines.** Confirmed by stakeholder as the target for future CI/CD work — no `ci/` directory or pipeline YAML exists in the repo yet; this decision is a requirement for the DevOps Developer to implement, not a record of prior implementation.
- ~~OQ12~~ **RESOLVED (2026-08-24)** — What is the target deployment environment topology? **Decision: single environment** (no dev/staging/prod split). Confirmed by stakeholder as the target for future infra work — no `infra/` directory or bicepparam file exists in the repo yet; this decision is a requirement to implement, not a record of prior implementation.
- ~~OQ13~~ **RESOLVED (2026-08-24)** — Does the core-config.yaml blanket Prisma-shadow-database governance clause apply to this workstream? **Decision: N/A — confirmed not applicable.** `common-reference-dataops` is a Python/pandas package with no Prisma/ORM in its stack; the Product Owner's original recommendation is confirmed as final. The rest of that governance convention (a `resourceGroupName` parameter on every provisioned resource/module, and an `ownerObjectIds` array receiving Owner role assignment on every provisioned resource) still applies unconditionally and remains a requirement for the future `modules/containerAppsJob.bicep` and `networking.bicep` implementation — no `infra/` directory exists in the repo yet, so this is a governance requirement to build to, not a record of prior implementation.

## 12. Change Log
| Version | Date | Author | Change |
|---|---|---|---|
| v0.1 | 2026-08-13 | Shiham (PO) | Initial draft: HireFlow Job Application screen (frontend localStorage-only + standalone backend persistence demo). |
| v0.2 | 2026-08-23 | Shiham (PO) | Added §11 Student/Subject/Grade Reporting Data Pipeline (Data Engineering workstream): goals G6-G10/NG6-NG9, personas, UC4-UC6, FR-SSGPIPE-1..8, NFRs, constraints, dependencies, and OQ4-OQ9. No architecture/implementation decisions made — captured business requirement only, per PO scope for DE workstreams. |
| v0.3 | 2026-08-23 | Shiham (PO) | Added deployment requirement for the `common-reference-dataops` package (canonical structure at `docs/development-standards/template/DataEnginnering/common-reference-dataops/`): G11, NG10-NG11, FR-SSGPIPE-9/10, DEPLOYMENT_STANDARDS dependency, and OQ10-OQ13 (hosting model, CI/CD platform, environment topology, and a flag on the core-config Prisma-shadow-database Azure governance clause's applicability to this Python/pandas package). No deployment architecture decided — captured business requirement only, per PO scope; routes to Data Architect/DevOps Developer via Team Lead. |
| v0.4 | 2026-08-24 | Shiham (PO) | Stakeholder confirmed deployment-architecture defaults: OQ10-OQ13 resolved and closed (not deleted, kept for traceability) — Azure Container Apps Jobs (scheduled + on-demand), Azure DevOps Pipelines, single environment topology, and Prisma-shadow-database clause confirmed N/A for this Python/pandas package (rest of the resourceGroupName/ownerObjectIds governance convention still applies unconditionally). Documentation-only change; no architecture/task/code changes made. |
| v0.5 | 2026-08-24 | Sanjeewa (TL) | Correction: v0.4's claim that these decisions matched an "already-implemented" `infra/common-reference-dataops/` and `ci/common-reference-dataops/` was inaccurate — no `infra/` or `ci/` directory exists in the repo; only `docs/development-standards/template/DataEnginnering/common-reference-dataops/` (the canonical template) exists. OQ10-OQ13 remain valid decisions but are requirements for future infra/CI/CD implementation, not a record of prior work. Corrected OQ10-OQ13 wording and §11.8 dependency path accordingly. Documentation-only change. |
| v0.6 | 2026-08-24 | Shiham (PO) | Schema correction: replaced stale/incorrect source-column references (`dob`, `enrollment_date`, `grade_date`, `score`) throughout §11 with the actual confirmed columns from `sample_data/students.csv`/`subjects.csv`/`grades.csv` (`date_of_birth`, `gender`, `subject_code`, `marks`, `exam_term`) — updated FR-SSGPIPE-1/2/3/4 and the §11.7 constraints note; removed the inapplicable enrollment_date/grade_date normalization claim (neither field exists in the real schema). New requirement: added G12, NG12, and FR-SSGPIPE-11..17 for grade-letter calculation from `marks` (configurable grading scale), marks range validation with rejected-record routing, forward-looking source-grade mismatch detection, Parquet delivery to Azure Data Lake Storage Gen2 (ingestion-date partitioned, Managed Identity/Key Vault auth, no hard-coded storage secrets), a deployable orchestrated pipeline deliverable, minimum execution metrics, and minimum automated test coverage. Updated NFR table (Observability, Security) accordingly. No architecture/implementation decisions made — business requirement capture only, per PO scope for DE workstreams; routes to Data Architect/DE PM via the Team Lead. |
