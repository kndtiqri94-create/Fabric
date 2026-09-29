---
name: fabric-pipeline-authoring
description: Author Microsoft Fabric Data Factory pipelines and Dataflows Gen2 as Git-tracked items — activity selection, parameterization, retries, failure paths, incremental watermarks. Use when building or changing anything under the Fabric pipelines root.
---

# Fabric pipeline authoring

Applies FABRIC_STANDARDS.md (Data Pipelines, Dataflows Gen2 sections). Load that first; this skill is the how-to.

## Choose the item
- Pure copy, no row logic → Copy activity.
- Sequencing/retries/schedule → pipeline; logic → notebook (call via Notebook activity).
- Analyst-shaped, small/medium → Dataflow Gen2 (only if the SDD says so).

## Item layout (Git format)
```
<Name>.DataPipeline/
  .platform                # logicalId/displayName — never hand-edit logicalId
  pipeline-content.json    # activities, parameters, variables
```
Verify the current definition schema in Microsoft docs before editing JSON by hand; prefer changing a known-good exported item over writing from scratch.

## Procedure
1. Read SDD (source, layers, load mode, schedule) and the DE Plan.
2. Define **pipeline parameters** first: `p_env`, `p_source`, `p_target_schema`, `p_window_start`, `p_window_end`, `p_run_id`. No literals for connection ids/item ids.
3. Compose the standard skeleton:
   `Get watermark (Lookup)` → `Copy/Notebook (bronze)` → `Notebook (silver)` → `Notebook (DQ, if required)` → `Commit watermark` → `Notify on failure`.
4. Set per-activity **retry / interval / timeout**. Non-idempotent steps: retry 0.
5. Wire failure paths to a notification activity (Teams/email/Web) with run context (`@pipeline().RunId`, pipeline name, window, error). Never end a failure path in a success state.
6. ForEach: set `batchCount`; child work goes in an invoked child pipeline.
7. Watermark: update only in the activity that runs **after** the data commit succeeds.
8. Schedule declared in the item/release script; name owner and expected duration in the description.
9. Validate JSON parses, parameters referenced exist, no GUIDs/secrets present (grep before hand-off).

## Checks before hand-off
- Run twice on the same window in test → identical row counts.
- Force a child failure → pipeline fails, alert fires, watermark unchanged.
- No source data in activity outputs surfaced to notifications.

## Do not
- Put business logic in expressions; embed credentials; create prod-only triggers by hand; use "upon completion" to hide failures.
