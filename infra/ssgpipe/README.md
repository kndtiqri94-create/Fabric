# ssgpipe — Infrastructure & Deployment

Infrastructure-as-code and deployment documentation for Workstream E-2
(Student/Subject/Grade Reporting Data Pipeline), per
`docs/data-engineering-design/2.1_SSGPIPE_SDD.md` §14 and
`docs/development-standards/DEPLOYMENT_STANDARDS.md`. This is **PyTIQ Data
Engineering track infra** — independent of the TIQRIDemo application's
`infra/` Bicep conventions (there is no TIQRIDemo overlap here; see
`docs/features/2.1_STUDENT_SUBJECT_GRADE_PIPELINE_DE_PLAN.md` §4.5).

## What this provisions

| Resource | Bicep module | Notes |
|---|---|---|
| User-assigned Managed Identity | `modules/managed-identity.bicep` | Sole credential surface for the pipeline. No storage account key/SAS/connection string is ever provisioned or referenced. |
| ADLS Gen2 storage account + `valid`/`rejected` containers | `modules/storage-adls.bicep` | Optional — see **Assumptions** below; `createStorageAccount=false` to reuse an existing account instead. |
| Storage Blob Data Contributor role assignment | `modules/rbac-storage-blob-contributor.bicep` | Least-privilege RBAC, scoped to the storage account only — not subscription/resource-group scope. |
| Container Apps managed environment | `modules/container-apps-environment.bicep` | Optional — `createContainerAppsEnvironment=false` to attach to an existing/shared environment instead. |
| Container Apps Job (scheduled trigger) | `modules/container-apps-job.bicep` | Runs the `ssgpipe` container image on a CRON schedule; on-demand runs use `az containerapp job start` (see below). |
| Optional Owner role assignments | `modules/rbac-owner-assignment.bicep` | Opt-in governance/break-glass mechanism (`ownerObjectIds`), empty by default — not required for the pipeline to run. |

**No Key Vault-held secret is required for this workstream beyond Managed
Identity federation.** The only non-secret configuration values (storage
account name, container names, schedule mode, grading table, DQ thresholds)
resolve via Azure App Configuration or an untracked local settings file, per
`simple_azure_utils.load_setting` (the same pattern already used by
`src/pytiq/connectors/sink/parquet_partition_sink_connector.py`). If a future
change introduces a genuine secret (e.g. a third-party API key), it MUST be
added to an Azure DevOps variable group backed by Key Vault — never a
plaintext pipeline variable — per `DEPLOYMENT_STANDARDS.md` and
`SECURITY_AND_PII_STANDARDS.md` rule 1.

## Assumptions (flagged, not guessed)

- **Storage account**: the SDD (§16 Dependencies: "an ADLS Gen2 storage
  account (to be provisioned)") and DE Plan (§4.5: "if not already
  provisioned") both leave open whether ssgpipe gets a dedicated storage
  account or reuses an existing/shared one. This template defaults to
  provisioning a **new, dedicated** account (`createStorageAccount=true`) as
  the safer default for a PII-bearing dataset (least blast radius, clean
  RBAC boundary) — set `createStorageAccount=false` and supply
  `existingStorageAccountName` to reuse a shared account instead. Confirm the
  intended choice with the Team Lead / Data Architect before a real
  production deployment.
- **Container Apps environment**: same reasoning applies — defaults to
  provisioning a new, dedicated environment (`createContainerAppsEnvironment=true`).
- **Retention/deletion policy** for the ADLS Gen2 output is **not** set by
  this template (SDD §11/§17 R3, OQ-DE2 — unresolved, non-blocking). Do not
  finalize a storage account lifecycle policy until Shiham (Product Owner)
  confirms a retention period.

## Local execution

Matches the template's existing runner convention (see
`docs/development-standards/template/DataEnginnering/common-reference-dataops/README.md`):

```bash
python -m runners.domain_runners.ssgpipe_runner \
  --env DEV \
  --settings-path infra/ssgpipe/config/pipeline-settings.json
```

- Copy `infra/ssgpipe/config/pipeline-settings.example.json` to
  `pipeline-settings.json` (untracked — already covered by `.gitignore`) and
  fill in real local paths/thresholds.
- Copy `src/pytiq/connectors/sink/resources/adls_gen2_settings.example.json`
  to `adls_gen2_settings.json` (untracked) for the storage account/container
  **setting names** the sink connector resolves — no secret value goes in
  either file; ADLS Gen2 auth is Managed Identity only. For a local run
  without a Container Apps-assigned identity, authenticate via `az login`
  first — `DefaultAzureCredential` falls back to your Azure CLI session.
- Use `--ac <app-config-name>` instead of `--settings-path` to resolve the
  same settings from Azure App Configuration.

## Azure deployment

1. Review/confirm the **Assumptions** above with the Team Lead / Data
   Architect for the target environment.
2. Copy `parameters/ssgpipe.parameters.example.json` to
   `ssgpipe.parameters.json` (untracked — covered by `.gitignore`) and fill
   in the real resource group, region, storage account name (globally
   unique), and App Configuration store name. **Never commit a copy with
   real values.**
3. Deploy the Bicep stack:

   ```bash
   az deployment group create \
     --resource-group <RESOURCE_GROUP_NAME> \
     --template-file infra/ssgpipe/main.bicep \
     --parameters infra/ssgpipe/parameters/ssgpipe.parameters.json
   ```

4. The CI/CD pipeline (`ci/ssgpipe-pipeline.yml`) automates steps 3+ as part
   of its Release stage on every merge to `main` — see that file for the
   full build → scan → image push → deploy → post-deploy health-check flow.
5. Populate the real, non-secret pipeline settings
   (`infra/ssgpipe/config/pipeline-settings.example.json` → your Azure App
   Configuration store, under the same setting names) and the sink
   connector's storage account/container setting values
   (`src/pytiq/connectors/sink/resources/adls_gen2_settings.example.json` →
   the same App Configuration store).

## Manual / on-demand execution

Scheduled runs (daily/weekly, per `scheduleCronExpression`) happen
automatically via the Container Apps Job's schedule trigger. An on-demand
run (FR-SSGPIPE-8/AC-11/AC-12) is triggered manually:

```bash
az containerapp job start \
  --name <CONTAINER_APPS_JOB_NAME> \
  --resource-group <RESOURCE_GROUP_NAME>
```

(`<CONTAINER_APPS_JOB_NAME>` is the `main.bicep` output `containerAppsJobName`.)

## Health check

Per `DEPLOYMENT_STANDARDS.md` rule 14 (mandatory — production-deployed,
scheduled/long-running): **the container's own entry point** (the runner at
`src/pytiq/pipelines/ssgpipe/runner.py`, owned by the pipeline development
specialists, not this infra template) MUST perform a pre-flight check
*before* running the main pipeline logic:

1. All three source files (Students, Subjects, Grades) are readable.
2. The Managed Identity attached to this job (`AZURE_CLIENT_ID`, wired in
   `modules/container-apps-job.bicep`) can successfully resolve an ADLS Gen2
   access token via `DefaultAzureCredential`.

If either check fails, the entry point MUST fail fast with a clear,
non-silent error — not fail deep inside transformation. This infra template
provisions and wires everything the health check needs (the identity, its
`AZURE_CLIENT_ID` env var, the RBAC role assignment) but does not itself
implement the check, which lives in application code per the DE Plan §4.6.
The CI/CD pipeline's post-deploy step (`ci/ssgpipe-pipeline.yml` → "Post-deploy
health check") triggers one on-demand run immediately after deployment so a
health-check failure surfaces in CI, not at the next scheduled trigger.

## Rollback

Per `DEPLOYMENT_STANDARDS.md` rule 15 (mandatory — production-deployed): the
documented rollback path is **redeploying the previous container image tag**
to the same Container Apps Job — either by re-running the CI/CD pipeline's
Release stage with `containerImage` pinned to a prior `$(Build.BuildId)` tag,
or directly:

```bash
az containerapp job update \
  --name <CONTAINER_APPS_JOB_NAME> \
  --resource-group <RESOURCE_GROUP_NAME> \
  --image <REGISTRY_LOGIN_SERVER>/ssgpipe:<PREVIOUS_TAG>
```

**No data migration is required.** Every ssgpipe run overwrites its own
ingestion-date partition idempotently (SDD §7/§9) — rolling back the
container image does not leave the ADLS Gen2 output in an inconsistent
state; the next run (scheduled or on-demand) under the rolled-back image
simply re-produces that day's partition.

## Configuration reference

| File | Contents | Tracked? |
|---|---|---|
| `config/pipeline-settings.example.json` | Source file paths, join keys, schedule mode/timezone, grading table, DQ thresholds, log level | Yes (example only) |
| `config/pipeline-settings.json` | Same, with real values | **No** — untracked, `.gitignore`d |
| `parameters/ssgpipe.parameters.example.json` | Bicep deployment parameters (region, RG name, storage/container names, image ref, schedule CRON) | Yes (example only, placeholders) |
| `parameters/ssgpipe.parameters.json` | Same, with real values | **No** — untracked, `.gitignore`d |
| `src/pytiq/connectors/sink/resources/adls_gen2_settings.example.json` | Storage account/container **setting names** for the sink connector | Yes (example only) |

No file in this list ever contains an access key, SAS token, or connection
string — ADLS Gen2 authentication is Managed Identity only, in every
environment.
