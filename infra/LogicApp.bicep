//NOTE: Some of these resouces cannot be deployed if the targetScope is subscription

//Deploy App Service Workflow Plan, LogicApp Workflow configured
//TODO: Wire up Instrumentation, possibly make optional
//TODO: Generate new workflow plan or leverage existing workflow plan selectively

//param workflowplanid string 
//param workspaceId string
//param appInsightsInstrumentationKey string

@description('The environment for which the deployment is being executed')
@allowed([
  'dev'
  'uat'
  'prod'
])
param deploymentEnvironment string

param uniqueSuffix string

@description('Location for all resources.')
param location string = resourceGroup().location

param workloadName string = 'schemaGen'

param managementbaseuri string = environment().resourceManager

var LogicAppPlan_name = '${workloadName}-WorkflowPlan-${uniqueSuffix}-${deploymentEnvironment}'
var LogicApp_Name = '${workloadName}-${uniqueSuffix}-${deploymentEnvironment}'
var prelim_LogicAppStorageName = replace(toLower('${workloadName}${uniqueSuffix}${deploymentEnvironment}'),'-','')

//substring will fail if the string isn't long enough, so need to test to see if needed
var LogicApp_Storage_Name = (length(prelim_LogicAppStorageName)<24 ? prelim_LogicAppStorageName :substring(prelim_LogicAppStorageName,0,23))

resource storageAccounts_WorkflowPlanStorage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: LogicApp_Storage_Name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  properties: {
    minimumTlsVersion:'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource:'Microsoft.Storage'
    }
  }
}
//Build the storage account connection string
var storagePrimaryKey = listKeys(storageAccounts_WorkflowPlanStorage.id, storageAccounts_WorkflowPlanStorage.apiVersion).keys[0].value
var storageprimaryConnStr = 'DefaultEndpointsProtocol=https;AccountName=${LogicApp_Storage_Name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storagePrimaryKey}'


resource workflowplan_serverfarms 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: LogicAppPlan_name
  location: location
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
    size: 'WS1'
    family: 'WS'
    capacity: 1
  }
  kind: 'elastic'
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: true
    maximumElasticWorkerCount: 20
    isSpot: false
    reserved: false
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}

resource sites_schemagen_name_resource 'Microsoft.Web/sites@2022-03-01' = {
  name: LogicApp_Name
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    serverFarmId: workflowplan_serverfarms.id  //want to pass this in as a parameter so we only have one workflow plan for the accelerator
    reserved: false
    isXenon: false
    hyperV: false
    vnetRouteAllEnabled: false
    vnetImagePullEnabled: false
    vnetContentShareEnabled: false
    siteConfig: {
      numberOfWorkers: 1
      acrUseManagedIdentityCreds: false
      alwaysOn: false
      http20Enabled: false
      functionAppScaleLimit: 0
      minimumElasticInstanceCount: 1
      appSettings:[
        {
        name: 'APP_KIND  '
        value: 'workflowapp'
        }
        {
          name: 'AzureWebJobsStorage'
          value: storageprimaryConnStr
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageprimaryConnStr
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'

        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: '[1.*, 2.0.0)'

        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'

        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'

        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(workloadName)

        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~14'

        }
        {
          name: 'WORKFLOWS_TENANT_ID'
          value: subscription().tenantId
        }
        {
          name: 'WORKFLOWS_SUBSCRIPTION_ID'
          value: subscription().id
        }
        {
          name: 'WORKFLOWS_RESOURCE_GROUP_NAME'
          value: resourceGroup().name
        }
        {
          name: 'WORKFLOWS_LOCATION_NAME'
          value: location
        }
        {
          name: 'WORKFLOWS_MANAGEMENT_BASE_URI'
          value: managementbaseuri
        }
      ]
    }
    scmSiteAlsoStopped: false
    clientAffinityEnabled: false
    clientCertEnabled: false
    clientCertMode: 'Required'
    hostNamesDisabled: false
    containerSize: 1536
    dailyMemoryTimeQuota: 0
    httpsOnly: true
    redundancyMode: 'None'
    storageAccountRequired: false
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
}

output LogicAppPlan_name string = LogicAppPlan_name
output LogicApp_name string = LogicApp_Name
output LogicApp_Storage_name string = LogicApp_Storage_Name
