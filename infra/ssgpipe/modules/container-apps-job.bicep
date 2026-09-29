// Azure Container Apps Job running the ssgpipe pipeline.
//
// Trigger type: **Scheduled** (`triggerType: 'Schedule'`) covers the
// daily/weekly modes (SDD §14/FR-SSGPIPE-8). On-demand execution is covered
// separately, outside this template, via `az containerapp job start` (or the
// equivalent Azure DevOps release-pipeline task) — see
// infra/ssgpipe/README.md "Manual / on-demand execution".
//
// Concurrency: `parallelism: 1` and `replicaCompletionCount: 1`, and the
// schedule trigger config's `replicaRetryLimit`/single-instance nature
// enforce SDD §7/Assumption A2 (no concurrent runs of this pipeline for the
// same ingestion date) at the infra level, not in pipeline code.
//
// Identity: only the user-assigned managed identity is attached — no
// system-assigned identity, no secrets block referencing a storage
// account key/connection string. `env` variables carry only NON-secret
// configuration (setting NAMES / App Configuration store name / schedule
// mode) — the actual storage account name/container name values are
// resolved at runtime by the pipeline via `simple_azure_utils.load_setting`
// from Azure App Configuration, not baked in here.

@description('Azure region for the Container Apps Job.')
param location string

@description('Name of the resource group this job is deployed into (exposed for tagging/traceability).')
param resourceGroupName string

@description('Name of the Container Apps Job resource.')
param jobName string = 'job-ssgpipe'

@description('Resource ID of the Container Apps managed environment hosting this job.')
param containerAppsEnvironmentId string

@description('Resource ID of the user-assigned managed identity attached to this job.')
param managedIdentityId string

@description('Client ID of the user-assigned managed identity (passed to DefaultAzureCredential via AZURE_CLIENT_ID so the SDK resolves THIS identity, not another one on the host).')
param managedIdentityClientId string

@description('Full container image reference to run, e.g. <REGISTRY_LOGIN_SERVER>/ssgpipe:<TAG>. Placeholder only — the CI/CD release stage supplies the real value per deployment.')
param containerImage string = '<REGISTRY_LOGIN_SERVER>/ssgpipe:<TAG>'

@description('CRON expression for the scheduled trigger (default: once daily at 02:00 UTC). Independent of pipeline logic per FR-SSGPIPE-8/AC-11 — change this value alone to change the schedule.')
param scheduleCronExpression string = '0 2 * * *'

@description('Azure App Configuration store name used to resolve non-secret pipeline configuration at runtime (per CONFIGURATION_STANDARDS.md / simple_azure_utils.load_setting). Leave empty to use a mounted local settings file instead (not recommended for production).')
param appConfigurationName string = ''

@description('Azure App Configuration label / environment name (e.g. DEV). Single-environment topology today per SDD §11/§13.')
param environmentLabel string = 'DEV'

@description('Container CPU allocation (cores).')
param cpuCores string = '0.5'

@description('Container memory allocation.')
param memory string = '1Gi'

@description('Common resource tags applied to this resource.')
param tags object = {}

resource containerAppsJob 'Microsoft.App/jobs@2024-03-01' = {
  name: jobName
  location: location
  tags: union(tags, {
    resourceGroup: resourceGroupName
    workstream: 'E-2-ssgpipe'
  })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironmentId
    configuration: {
      triggerType: 'Schedule'
      replicaTimeout: 1800
      replicaRetryLimit: 1
      scheduleTriggerConfig: {
        cronExpression: scheduleCronExpression
        parallelism: 1
        replicaCompletionCount: 1
      }
      // No `secrets` block: Managed Identity is the only credential surface
      // for this job (SDD §11/§14, SECURITY_AND_PII_STANDARDS.md rule 1) —
      // there is no storage account key/SAS/connection-string secret to
      // declare here.
    }
    template: {
      containers: [
        {
          name: 'ssgpipe'
          image: containerImage
          resources: {
            cpu: json(cpuCores)
            memory: memory
          }
          // Health check (DEPLOYMENT_STANDARDS.md rule 14): the container's
          // own entry point MUST run a pre-flight check (all three source
          // files readable + Managed Identity can resolve an ADLS Gen2
          // token) before the main pipeline logic — implemented in the
          // runner entry point (src/pytiq/pipelines/ssgpipe/runner.py, per
          // the DE Plan §4.6), NOT in this infra template. This job
          // definition wires the identity/config the health check needs;
          // see infra/ssgpipe/README.md "Health check" for the contract.
          env: [
            {
              name: 'AZURE_CLIENT_ID'
              value: managedIdentityClientId
            }
            {
              name: 'SSGPIPE_APP_CONFIG_NAME'
              value: appConfigurationName
            }
            {
              name: 'SSGPIPE_ENVIRONMENT_LABEL'
              value: environmentLabel
            }
            {
              name: 'SSGPIPE_SCHEDULE_MODE'
              value: 'scheduled'
            }
          ]
        }
      ]
    }
  }
}

output jobId string = containerAppsJob.id
output jobName string = containerAppsJob.name
