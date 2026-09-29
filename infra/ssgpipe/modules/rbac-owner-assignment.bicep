// Optional Owner role assignments on the resource group, for named
// governance/break-glass principals (e.g. the platform team, or named human
// owners) — per the DevOps Developer persona's requirement that every
// provisioned Azure resource group expose an `ownerObjectIds` assignment
// path. Deliberately opt-in: `ownerObjectIds` defaults to an empty array,
// so no Owner role is granted unless the caller explicitly supplies object
// IDs at deploy time. This is NOT how the pipeline itself authenticates —
// the pipeline uses ONLY the least-privilege Storage Blob Data Contributor
// role via modules/rbac-storage-blob-contributor.bicep.

targetScope = 'resourceGroup'

@description('AAD object IDs to grant the built-in Owner role on this resource group. Leave empty to skip (default) — this is a governance/break-glass mechanism, not required for the pipeline to function.')
param ownerObjectIds array = []

@description('Principal type for each entry in ownerObjectIds (User, Group, or ServicePrincipal). All entries must share the same type in this simple loop; split into multiple deployments if a mix is needed.')
@allowed(['User', 'Group', 'ServicePrincipal'])
param ownerPrincipalType string = 'Group'

// Owner — built-in role definition ID (fixed GUID).
var ownerRoleId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'

resource ownerAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for objectId in ownerObjectIds: {
    name: guid(resourceGroup().id, objectId, ownerRoleId)
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', ownerRoleId)
      principalId: objectId
      principalType: ownerPrincipalType
    }
  }
]
