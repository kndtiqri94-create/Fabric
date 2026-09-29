---
name: fabric-cicd-deployment
description: Fabric workspace, Git integration, deployment-pipeline and scripted release (fabric-cicd / Fabric REST API) work — environment parameterization, service-principal auth, smoke test, rollback. Use when Milinda handles the Fabric DevOps track.
---

# Fabric CI/CD & deployment

Applies FABRIC_STANDARDS.md (Workspace/Git/Environments, Deployment and Promotion) plus DEPLOYMENT_STANDARDS.md and SECURITY_AND_PII_STANDARDS.md.

## Promotion model
`feature branch → PR → main → dev workspace (Git sync) → test → prod`. Only dev is Git-connected. Test/prod are populated by a **Fabric deployment pipeline** or a scripted release (Python `fabric-cicd` library or the Fabric REST API, base `https://api.fabric.microsoft.com/v1`). Confirm the current capabilities of each before choosing; record the choice in the SDD.

## Procedure
1. Read SDD §14 (target: workspaces, capacity, promotion tool) and DE Plan §4.5.
2. Repo layout under the Fabric deploy root: `deploy/` (release script, `parameter` file per environment), `.<pipeline>` CI YAML in the project's CI system (Azure DevOps / GitHub Actions — follow the SDD; do not assume).
3. Environment mapping: connections, lakehouse/warehouse ids, capacities via deployment rules / parameter file / variable-library value sets. The release **fails** if a mapping is missing.
4. Auth: service principal (secret/cert from Key Vault or federated credential) with least-privilege workspace role. No secrets or real GUIDs in the repo — parameter files reference names/secret refs, values come from the secret store or pipeline variables.
5. Release stages: validate (lint, secret scan, unit tests) → deploy to test → smoke run + reconcile → manual approval → deploy to prod → post-deploy health check.
6. Idempotent: re-running a release converges.
7. Rollback: redeploy previous tag; Delta `RESTORE` for data within retention — document both in the runbook.
8. Capacity: document SKU, pause/resume policy if any, and who owns cost.

## Do not
Edit prod in UI; use personal accounts for release; hardcode workspace/tenant ids; touch notebook/pipeline logic (that's Chamath/Smrithika).
