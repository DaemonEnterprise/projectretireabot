targetScope = 'resourceGroup'

import {
  AzureDevOpsOptions
  GitHubOptions
  PowerBIOptions
} from 'types.bicep'

param deploymentSuffix string
param location string

param azureDevOpsOptions AzureDevOpsOptions
param gitHubOptions GitHubOptions
param powerBIOptions PowerBIOptions

param dataSinkBackend string[]
param workItemBackend string[]

var keyVaultResourceName = 'kv-${deploymentSuffix}'
resource vault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: keyVaultResourceName
  location: location
  properties: {
    createMode: 'default'
    enableRbacAuthorization: true
    enableSoftDelete: true
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    publicNetworkAccess: 'Enabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: 7
    tenantId: deployer().tenantId
  }
}

resource gitHubSecret 'Microsoft.KeyVault/vaults/secrets@2025-05-01' = if (!empty(gitHubOptions.PAT) && contains(
  workItemBackend,
  'GitHub'
)) {
  parent: vault
  name: 'Github--PAT'
  properties: {
    value: gitHubOptions.PAT
  }
}

resource adoPATSecret 'Microsoft.KeyVault/vaults/secrets@2025-05-01' = if (!empty(azureDevOpsOptions.PAT) && contains(
  workItemBackend,
  'AzureDevOps'
)) {
  parent: vault
  name: 'AzureDevOps--PAT'
  properties: {
    value: azureDevOpsOptions.PAT
  }
}

resource adoClientSecretSecret 'Microsoft.KeyVault/vaults/secrets@2025-05-01' = if (!empty(azureDevOpsOptions.clientSecret) && contains(
  workItemBackend,
  'AzureDevOps'
)) {
  parent: vault
  name: 'AzureDevOps--ClientSecret'
  properties: {
    value: azureDevOpsOptions.clientSecret
  }
}

resource powerBIClientSecretSecret 'Microsoft.KeyVault/vaults/secrets@2025-05-01' = if (!empty(powerBIOptions.clientSecret) && contains(
  dataSinkBackend,
  'PowerBI'
)) {
  parent: vault
  name: 'PowerBI--ClientSecret'
  properties: {
    value: powerBIOptions.clientSecret
  }
}

output name string = vault.name
output uri string = vault.properties.vaultUri
