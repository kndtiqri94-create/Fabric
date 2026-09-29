---
name: fabric-lakehouse-notebooks
description: Build Fabric Spark notebooks and Lakehouse Delta tables — medallion layers, idempotent MERGE/partition-overwrite writes, parameter cells, shared modules, structured exit values, Delta maintenance. Use when working under the Fabric notebooks or lakehouse roots.
---

# Fabric Lakehouse & notebooks

Applies FABRIC_STANDARDS.md (OneLake/Lakehouse/Delta, Notebooks). Load it first.

## Item layout (Git format)
```
<Name>.Notebook/   .platform + notebook-content.py (or .ipynb)
<Name>.Lakehouse/  .platform (+ definition); tables are data, not source-controlled
```
Reusable logic → a module (Fabric Environment library / wheel / `%run` module notebook) that is importable and unit-testable with pytest outside Fabric.

## Notebook skeleton
1. **Parameters cell** (tagged): `p_env`, `p_layer`, `p_source_table`, `p_target_table`, `p_window_start`, `p_window_end`, `p_run_id`.
2. Imports of the shared module; config resolved from variable library/parameters.
3. Read (bounded to the window) → transform (delegate to module) → write.
4. Return `notebookutils.notebook.exit(json.dumps({...status, rows_in, rows_out, rows_rejected, run_id}))`; **raise** on failure.

## Write patterns (pick per SDD)
- Bronze: `append` with `_ingest_run_id`, `_ingested_at`, `_source_system`; dedupe by run id on re-run.
- Silver: Delta `MERGE` on the declared business key (`whenMatchedUpdate` with change condition, `whenNotMatchedInsert`).
- Gold partition refresh: `overwrite` with `replaceWhere` on the partition predicate.
- Never blind-overwrite a table others read. Never enable global `mergeSchema`.

## Maintenance (production)
Scheduled notebook: `OPTIMIZE <table>`, `VACUUM <table> RETAIN <hours>` (≥168h unless an exception is recorded). Log table sizes/file counts.

## Secrets & data safety
- Secrets via `notebookutils.credentials.getSecret(<kv-uri>, <name>)` or workspace identity — never in cells/params.
- No `display()/show()/print/collect()` of sensitive rows. Log counts and ids only. Strip outputs before commit.

## Checks before hand-off
- Unit tests on the module pass; run notebook twice on one window in test → identical result.
- Schema of output matches the data contract; drift path documented.
- Runtime/library versions pinned in the Environment item.
