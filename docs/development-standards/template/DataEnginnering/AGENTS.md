<!-- bmad:context -->
<!-- Verified 2026-08-23 against working tree (no VCS — not yet a git repo). Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## DG Geo Infrastructure

Reference-data ingestion template: source connectors (Azure SQL, Google Sheets) feed a shared transformer, which lands output in an Azure SQL sink. Python 3.12. `common-reference-dataops/` is the implemented package; `domain-pipelines/` is an empty placeholder with no decided purpose yet. Per-package usage docs live in `common-reference-dataops/README.md`.

## Policy

- Never commit real credentials or settings files — connection info resolves via Azure App Configuration or a local `--settings-path` file, and that file must never be tracked.
- Never hand-edit tables written by `AzureSQLSinkConnector` — schema and data are pipeline-managed; changes go through a runner.
- Never log or export source/reference data (addresses, coordinates, etc.) outside the configured sink — treat it as sensitive.

## Where things are

- Package template and instantiation steps: `common-reference-dataops/README.md`
- Runner entry points: `common-reference-dataops/runners/domain_runners/`
- SQL queries for the commonref runner: `common-reference-dataops/resources/domain_resources/queries/*.sql` (filename stem = target table)
- Google Sheet runner config: `common-reference-dataops/resources/domain_resources/google_sheets/google_sheet_config.json` (copy from the `.example.json` alongside it)

## Running and verifying

- No test suite or CI exists yet — there is nothing to run beyond the runners themselves.
- `.venv` at the repo root is broken (its `pyvenv.cfg` points at a Python install under a different Windows user) — recreate it before trying to run anything locally.

## Conventions that differ from defaults

- New pipelines follow the established split: a source connector (`connectors/sources/`) feeds a transformer (`transformations/`), written by a sink connector (`connectors/sink/`), wired together in one runner class under `runners/<domain>_runners/` — mirror `common-reference-dataops`'s `domain_*` naming for a new pipeline's package.
- Every transformer's output must pass through `AuditHelper.add_audit_columns` (adds `audit_digest`, `pipeline_run_time`) before it reaches a sink — don't bypass it.

<!-- /bmad:context -->
