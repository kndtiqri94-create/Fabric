// User-assigned Managed Identity for the ssgpipe Container Apps Job.
//
// This identity is the ONLY authentication mechanism the pipeline uses to
// reach ADLS Gen2 (per SDD §11/§14 — no storage account key, SAS token, or
// connection string is ever provisioned). It is attached to the Container
// Apps Job in modules/container-apps-job.bicep and granted the Storage Blob
// Data Contributor role on the target storage account in
// modules/rbac-storage-blob-contributor.bicep.

@description('Azure region for the identity (matches the resource group location).')
param location string

@description('Name of the resource group this identity is deployed into (exposed for tagging/traceability, not used to change deployment scope).')
param resourceGroupName string

@description('Name of the user-assigned managed identity resource.')
param identityName string = 'id-ssgpipe-job'

@description('Common resource tags applied to every resource in this module.')
param tags object = {}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: union(tags, {
    resourceGroup: resourceGroupName
    workstream: 'E-2-ssgpipe'
  })
}

output identityId string = identity.id
output identityPrincipalId string = identity.properties.principalId
output identityClientId string = identity.properties.clientId
output identityName string = identity.name
