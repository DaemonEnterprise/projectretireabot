targetScope = 'resourceGroup'

param deploymentSuffix string
param location string

var logAnalyticsWorkspaceResourceName = 'log-${deploymentSuffix}'
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: logAnalyticsWorkspaceResourceName
  location: location
  properties: {
    features: {
      searchVersion: 1
      enableLogAccessUsingOnlyResourcePermissions: true
      disableLocalAuth: true
    }
    retentionInDays: 365
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    forceCmkForQuery: true
  }
  sku: {
    name: 'PerGB2018'
  }
}

resource applicationEventDataSource 'Microsoft.OperationalInsights/workspaces/dataSources@2025-07-01' = {
  parent: logAnalyticsWorkspace
  name: 'applicationEvent'
  kind: 'WindowsEvent'
  properties: {
    eventLogName: 'Application'
    eventTypes: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
      {
        eventType: 'Information'
      }
    ]
  }
}

resource processorTimeDataSource 'Microsoft.OperationalInsights/workspaces/dataSources@2025-07-01' = {
  parent: logAnalyticsWorkspace
  name: 'windowsPerfCounter1'
  kind: 'WindowsPerformanceCounter'
  properties: {
    counterName: '% Processor Time'
    instanceName: '*'
    intervalSeconds: 60
    objectName: 'Processor'
  }
}

resource iisLogsDataSource 'Microsoft.OperationalInsights/workspaces/dataSources@2025-07-01' = {
  parent: logAnalyticsWorkspace
  name: 'sampleIISLog1'
  kind: 'IISLogs'
  properties: {
    state: 'OnPremiseEnabled'
  }
}

resource logAnalyticsWorkspaceDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${logAnalyticsWorkspace.name}-diagnosticSettings'
  scope: logAnalyticsWorkspace
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

var applicationInsightsResourceName = 'appi-${deploymentSuffix}'
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsResourceName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    DisableLocalAuth: true
  }
}

output appInsightsName string = applicationInsights.name
output workspaceResourceId string = logAnalyticsWorkspace.id
output instrumentationKey string = applicationInsights.properties.InstrumentationKey!
output connectionString string = applicationInsights.properties.ConnectionString!
