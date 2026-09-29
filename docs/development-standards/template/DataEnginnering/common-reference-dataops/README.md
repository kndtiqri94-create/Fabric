# Common Reference DataOps — Template

Generic scaffold for a "reference data" ingestion project: pulls from one or
more sources (Azure SQL, Google Sheets) and lands the result in an Azure SQL
sink, with a shared transformation + audit step in between.

## Layout

- `connectors/sources/` — read-side connectors (Azure SQL, Google Sheets).
- `connectors/sink/` — write-side connector (Azure SQL).
- `transformations/domain_transformer.py` — shared transform step; extend
  `_build_final_output_dataframe` with real business logic.
- `helpers/` — logging setup and audit-column helper (digest + run timestamp).
- `runners/domain_runners/` — entry points that wire a source, the
  transformer, and the sink together for one pipeline.
- `resources/domain_resources/queries/` — `*.sql` files for
  `domain_commonref_runner.py`; each file's stem becomes the sink table name.
- `resources/domain_resources/google_sheets/google_sheet_config.example.json`
  — copy to `google_sheet_config.json` and fill in for
  `domain_google_sheet_runner.py`.

## Using this as a starting point for a new project

1. Rename `domain_*` files/classes/folders to your project's domain
   (e.g. `runners/domain_runners` → `runners/<project>_runners`,
   `DomainTransformer` → `<Project>Transformer`).
2. Add `*.sql` files to `resources/domain_resources/queries/` for
   Azure SQL → Azure SQL pipelines, or copy
   `google_sheet_config.example.json` to `google_sheet_config.json` for
   Google Sheets → Azure SQL pipelines.
3. Update the setting names passed into `AzureSQLSourceConnector` /
   `AzureSQLSinkConnector` in the runner(s) to match your app config /
   settings store entries (server, database, username, password).
4. Extend `DomainTransformer._build_final_output_dataframe` with
   project-specific transformation logic.
5. Run a runner directly, e.g.:
   `python -m runners.domain_runners.domain_commonref_runner --env DEV --ac <app-config-name>`

## Notes

- `AuditHelper` adds `audit_digest` (row hash) and `pipeline_run_time`
  (UTC) columns to every output DataFrame — keep this in the transform
  chain so downstream tables stay auditable.
- Both runners resolve credentials via `simple_azure_utils.load_setting`,
  which supports Azure App Configuration or a local `settings_path` file —
  pass `--settings-path` for local runs.
