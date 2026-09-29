// Grants the ssgpipe job's user-assigned managed identity the MINIMUM RBAC
// role needed to read/write the pipeline's Parquet output on ADLS Gen2 —
// Storage Blob Data Contributor — scoped to the storage account only (not
// subscription/resource-group scope), per SECURITY_AND_PII_STANDARDS.md
// rule 4 (least privilege) and rule 1 (no static credential at all).

@description('Resource ID of the target ADLS Gen2 storage account (new or existing).')
param storageAccountId string

@description('Principal (object) ID of the user-assigned managed identity to grant access to.')
param principalId string

// Storage Blob Data Contributor — built-in role definition ID (fixed GUID,
// same across all Azure tenants/subscriptions).
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource storageAccountRef 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: last(split(storageAccountId, '/'))
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, principalId, storageBlobDataContributorRoleId)
  scope: storageAccountRef
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = roleAssignment.id
