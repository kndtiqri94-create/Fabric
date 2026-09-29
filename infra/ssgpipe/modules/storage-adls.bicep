// ADLS Gen2 storage account + containers for ssgpipe output.
//
// ASSUMPTION (see infra/ssgpipe/README.md "Assumptions" section): the SDD/DE
// Plan do not confirm whether ssgpipe gets its own dedicated storage account
// or reuses an existing/shared ADLS Gen2 account. This module supports BOTH
// paths via `createStorageAccount`:
//   - true  (default): provisions a new, dedicated storage account + two
//            containers (valid, rejected) for this workstream.
//   - false: skips provisioning; the caller supplies the existing storage
//            account name via `existingStorageAccountName` and RBAC is
//            still assigned against that existing account
//            (see modules/rbac-storage-blob-contributor.bicep).
//
// No access key, SAS token, or connection string is output or referenced
// anywhere in this module — access is exclusively via Managed Identity RBAC.

@description('Azure region for the storage account.')
param location string

@description('Name of the resource group this storage account is deployed into (exposed for tagging/traceability).')
param resourceGroupName string

@description('Whether to provision a new dedicated storage account for ssgpipe. Set false to reuse an existing/shared ADLS Gen2 account.')
param createStorageAccount bool = true

@description('Storage account name to create when createStorageAccount=true. Placeholder only — replace with a real globally-unique name at deploy time, never commit a real name to a tracked parameter file.')
@minLength(3)
@maxLength(24)
param newStorageAccountName string = '<STORAGE_ACCOUNT_NAME>'

@description('Existing storage account name to reuse when createStorageAccount=false.')
param existingStorageAccountName string = '<STORAGE_ACCOUNT_NAME>'

@description('Container name for the valid (DQ-passed, graded) dataset.')
param validContainerName string = 'ssgpipe-valid'

@description('Container name for the rejected (DQ-failed) dataset.')
param rejectedContainerName string = 'ssgpipe-rejected'

@description('Common resource tags applied to every resource in this module.')
param tags object = {}

var effectiveStorageAccountName = createStorageAccount ? newStorageAccountName : existingStorageAccountName

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = if (createStorageAccount) {
  name: newStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: union(tags, {
    resourceGroup: resourceGroupName
    workstream: 'E-2-ssgpipe'
  })
  properties: {
    isHnsEnabled: true // Hierarchical namespace — required for ADLS Gen2.
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // Enforce Managed Identity / RBAC-only access — no account-key auth path exists.
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Deny' // Deny-by-default network posture; the Container Apps Job's outbound identity authenticates via Azure AD, not network trust.
      bypass: 'AzureServices'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = if (createStorageAccount) {
  parent: storageAccount
  name: 'default'
}

resource validContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = if (createStorageAccount) {
  parent: blobService
  name: validContainerName
  properties: {
    publicAccess: 'None'
  }
}

resource rejectedContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = if (createStorageAccount) {
  parent: blobService
  name: rejectedContainerName
  properties: {
    publicAccess: 'None'
  }
}

output storageAccountName string = effectiveStorageAccountName
output storageAccountId string = createStorageAccount ? storageAccount.id : resourceId('Microsoft.Storage/storageAccounts', existingStorageAccountName)
output validContainerName string = validContainerName
output rejectedContainerName string = rejectedContainerName
