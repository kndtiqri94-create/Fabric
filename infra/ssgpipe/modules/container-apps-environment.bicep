// Container Apps managed environment (hosting boundary for the ssgpipe Job).
//
// SDD §16 lists "a Container Apps environment" as an external dependency
// without stating whether it is dedicated to ssgpipe or a shared environment
// used by other jobs/apps. This module supports both:
//   - createEnvironment=true (default): provisions a new, dedicated
//     Container Apps environment + Log Analytics workspace for ssgpipe.
//   - createEnvironment=false: skips provisioning; the caller supplies
//     `existingEnvironmentId` to attach the Job to an already-existing
//     (possibly shared) Container Apps environment instead.

@description('Azure region for the environment.')
param location string

@description('Name of the resource group this environment is deployed into (exposed for tagging/traceability).')
param resourceGroupName string

@description('Whether to provision a new, dedicated Container Apps environment for ssgpipe.')
param createEnvironment bool = true

@description('Name for the new Container Apps environment when createEnvironment=true.')
param environmentName string = 'cae-ssgpipe'

@description('Name for the new Log Analytics workspace backing the new environment.')
param logAnalyticsWorkspaceName string = 'log-ssgpipe'

@description('Resource ID of an existing Container Apps environment to reuse when createEnvironment=false.')
param existingEnvironmentId string = ''

@description('Common resource tags applied to every resource in this module.')
param tags object = {}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = if (createEnvironment) {
  name: logAnalyticsWorkspaceName
  location: location
  tags: union(tags, {
    resourceGroup: resourceGroupName
    workstream: 'E-2-ssgpipe'
  })
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = if (createEnvironment) {
  name: environmentName
  location: location
  tags: union(tags, {
    resourceGroup: resourceGroupName
    workstream: 'E-2-ssgpipe'
  })
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        // Both the workspace resource above and this resource share the
        // same `createEnvironment` condition, so `logAnalyticsWorkspace` is
        // always defined whenever this block actually executes — the
        // compiler's null-safety warning here is a known false positive for
        // same-condition conditional resource references.
        #disable-next-line BCP318 BCP422
        customerId: logAnalyticsWorkspace.properties.customerId
        // Resolved via the ARM listKeys() runtime function at deployment
        // time only — never a literal/committed value, never logged or
        // output from this template.
        #disable-next-line BCP318 BCP422
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

output environmentId string = createEnvironment ? containerAppsEnvironment.id : existingEnvironmentId
