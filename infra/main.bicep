targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Optional parameters to override the default azd resource naming conventions. Update the main.parameters.json file to provide values. e.g.,:
// "resourceGroupName": {
//      "value": "myGroupName"
// }
param appServicePlanName string = ''
param resourceGroupName string = 'rg-${environmentName}'
param webServiceName string = ''
// serviceName is used as value for the tag (azd-service-name) azd uses to identify
param serviceName string = 'lga'

@description('Id of the user or app to assign application roles')
param principalId string = ''

param uniqueSuffix string = substring(uniqueString(concat(subscription().id),environmentName),0,5)
var tags = { 'azd-env-name': environmentName }
var workloadName = 'la-std-basics'
var resourceSuffix = '${workloadName}-${environmentName}'

resource RG 'Microsoft.Resources/resourceGroups@2022-09-01' ={
  name: resourceGroupName
  location: location
  tags: union(tags, { 'azd-service-name': serviceName })
}

module LogicAppDeploy 'LogicApp.bicep' = {
  name: 'LogicAppDeploy'
  scope: resourceGroup(RG.name)
  params:{
    deploymentEnvironment: environmentName
    uniqueSuffix: uniqueSuffix
    location: location
    workloadName: workloadName
    environmentName:environmentName
  }
}

output LogicAppPlan_name string = LogicAppDeploy.outputs.LogicAppPlan_name
output LogicApp_name string = LogicAppDeploy.outputs.LogicApp_name
output LogicApp_Storage_name string = LogicAppDeploy.outputs.LogicApp_Storage_name
output ResourceGroupName string = resourceGroupName
