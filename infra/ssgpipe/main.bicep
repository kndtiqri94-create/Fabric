// ssgpipe (Workstream E-2 — Student/Subject/Grade Reporting Data Pipeline)
// Azure infrastructure — per docs/data-engineering-design/2.1_SSGPIPE_SDD.md §14.
//
// PyTIQ Data Engineering track infra — NOT part of the TIQRIDemo application's
// infra/ (Bicep conventions here are intentionally independent; see
// docs/features/2.1_STUDENT_SUBJECT_GRADE_PIPELINE_DE_PLAN.md §4.5).
//
// Deploy at resource-group scope, e.g.:
//   az deployment group create \
//     --resource-group <RESOURCE_GROUP_NAME> \
//     --template-file infra/ssgpipe/main.bicep \
//     --parameters infra/ssgpipe/parameters/ssgpipe.parameters.example.json
//
// See infra/ssgpipe/README.md for the full deployment walkthrough, including
// assumptions about the storage account and Container Apps environment.

targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Name of the resource group this stack is deployed into — used for tagging/traceability on every resource, not to change deployment scope (scope is set by the `az deployment group create --resource-group` invocation itself).')
param resourceGroupName string = resourceGroup().name

@description('Whether to provision a new, dedicated ADLS Gen2 storage account for ssgpipe. See README "Assumptions" — set false and supply existingStorageAccountName to reuse a shared/existing account instead.')
param createStorageAccount bool = true

@description('New storage account name (only used when createStorageAccount=true). Placeholder — replace at deploy time; never commit a real globally-unique name here.')
param newStorageAccountName string = '<STORAGE_ACCOUNT_NAME>'

@description('Existing storage account name (only used when createStorageAccount=false).')
param existingStorageAccountName string = '<STORAGE_ACCOUNT_NAME>'

@description('Container name for the valid (DQ-passed, graded) dataset.')
param validContainerName string = 'ssgpipe-valid'

@description('Container name for the rejected (DQ-failed) dataset.')
param rejectedContainerName string = 'ssgpipe-rejected'

@description('Whether to provision a new, dedicated Container Apps environment for ssgpipe. Set false and supply existingContainerAppsEnvironmentId to attach to a shared/existing environment instead.')
param createContainerAppsEnvironment bool = true

@description('Resource ID of an existing Container Apps environment (only used when createContainerAppsEnvironment=false).')
param existingContainerAppsEnvironmentId string = ''

@description('Container image reference for the ssgpipe job. Supplied by the CI/CD release stage at deploy time — placeholder only.')
param containerImage string = '<REGISTRY_LOGIN_SERVER>/ssgpipe:<TAG>'

@description('CRON expression for the scheduled trigger (daily/weekly modes). On-demand execution is a separate `az containerapp job start` invocation — see README.')
param scheduleCronExpression string = '0 2 * * *'

@description('Azure App Configuration store name for non-secret pipeline configuration (storage account/container setting names, schedule mode, grading table, DQ thresholds). Leave empty to fall back to a mounted local settings file (not recommended for production — see README).')
param appConfigurationName string = ''

@description('Azure App Configuration label / environment name. Single-environment topology today (SDD §11/§13, PRD OQ12).')
param environmentLabel string = 'DEV'

@description('AAD object IDs to grant the built-in Owner role on this resource group. Empty by default — opt-in governance mechanism only, not required for the pipeline itself to run (see modules/rbac-owner-assignment.bicep).')
param ownerObjectIds array = []

@description('Common resource tags applied across all resources in this stack.')
param tags object = {
  workstream: 'E-2-ssgpipe'
  managedBy: 'bicep'
}

// --- Managed Identity (sole credential surface for the pipeline) ---
module managedIdentity 'modules/managed-identity.bicep' = {
  name: 'ssgpipe-managed-identity'
  params: {
    location: location
    resourceGroupName: resourceGroupName
    tags: tags
  }
}

// --- ADLS Gen2 storage (new or existing, per createStorageAccount) ---
module storage 'modules/storage-adls.bicep' = {
  name: 'ssgpipe-storage'
  params: {
    location: location
    resourceGroupName: resourceGroupName
    createStorageAccount: createStorageAccount
    newStorageAccountName: newStorageAccountName
    existingStorageAccountName: existingStorageAccountName
    validContainerName: validContainerName
    rejectedContainerName: rejectedContainerName
    tags: tags
  }
}

// --- Least-privilege RBAC: Storage Blob Data Contributor, scoped to the storage account only ---
module storageRbac 'modules/rbac-storage-blob-contributor.bicep' = {
  name: 'ssgpipe-storage-rbac'
  params: {
    storageAccountId: storage.outputs.storageAccountId
    principalId: managedIdentity.outputs.identityPrincipalId
  }
}

// --- Container Apps environment (new or existing, per createContainerAppsEnvironment) ---
module containerAppsEnvironment 'modules/container-apps-environment.bicep' = {
  name: 'ssgpipe-container-apps-environment'
  params: {
    location: location
    resourceGroupName: resourceGroupName
    createEnvironment: createContainerAppsEnvironment
    existingEnvironmentId: existingContainerAppsEnvironmentId
    tags: tags
  }
}

// --- Container Apps Job (scheduled trigger; manual/on-demand runs via `az containerapp job start`) ---
module containerAppsJob 'modules/container-apps-job.bicep' = {
  name: 'ssgpipe-container-apps-job'
  params: {
    location: location
    resourceGroupName: resourceGroupName
    containerAppsEnvironmentId: containerAppsEnvironment.outputs.environmentId
    managedIdentityId: managedIdentity.outputs.identityId
    managedIdentityClientId: managedIdentity.outputs.identityClientId
    containerImage: containerImage
    scheduleCronExpression: scheduleCronExpression
    appConfigurationName: appConfigurationName
    environmentLabel: environmentLabel
    tags: tags
  }
}

// --- Optional governance Owner role assignments (opt-in, empty by default) ---
module ownerAssignments 'modules/rbac-owner-assignment.bicep' = {
  name: 'ssgpipe-owner-assignments'
  params: {
    ownerObjectIds: ownerObjectIds
  }
}

output managedIdentityClientId string = managedIdentity.outputs.identityClientId
output storageAccountName string = storage.outputs.storageAccountName
output containerAppsJobName string = containerAppsJob.outputs.jobName
output containerAppsEnvironmentId string = containerAppsEnvironment.outputs.environmentId
