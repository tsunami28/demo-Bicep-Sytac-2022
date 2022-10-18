//az monitor diagnostic-settings categories list --resource '/subscriptions/6a6bd9a3-cfe7-4598-84cc-c5a97303df4c/resourceGroups/vwan-poc-01-rg/providers/Microsoft.Network/azureFirewalls/fw-mkatinski-poc' -otsv --query 'value[*].[name]' 

@description('Name of the Azure Firewall.')
param AzureFWname string

@description('Name of the vNet to deploy the Azure Firewall which must be within the same Resource Group.')
param vnetName string

@description('Subnet name, this requires to be **AzureFirewallSubnet**')
@allowed([
  'AzureFirewallSubnet'
  'AzureFirewallManagementSubnet'
])
param subnetName string = 'AzureFirewallSubnet'

@description('The location where the infra vnet is deployed.')
@allowed([
  'northeurope'
  'westeurope'
])
param location string

@description('Azure Firewall Threat Intel Mode, default Deny.')
@allowed([
  'Alert'
  'Deny'
  'Off'
])
param threatIntelMode string = 'Deny'

@description('Availability Zone numbers e.g. 1,2,3. Default are the zones 1, 2 and 3.')
param availabilityZones array = [
  1
  2
  3
]

@description('Application Rule Collection (FQDN) including Security rule (s) object for the Azure Firewall.')
param applicationRuleCollections array = []

@description('Network Rule Collection (Outbound traffic filtering) including Security rule(s) object for the Azure Firewall.')
param networkRuleCollections array = []

@description('NAT Rule Collection (Inbound traffic filtering) including Security rule(s) object for the Azure Firewall.')
param natRuleCollections array = []

param logAnalyticsWorkspaceId string = ''

param diagnosticStorageAccountId string = '/subscriptions/2348f252-5d66-4ed8-b6b3-86b9a5825ba7/resourceGroups/demo-sytac-2022/providers/Microsoft.Storage/storageAccounts/diagazfwdemo'

param enableDiagnostics bool = false

param isSecuredHubFirewall bool = false

param firewallPolicyId string = ''

param hubId string = ''

var azureFirewallSubnetId = '${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/virtualNetworks/${vnetName}/subnets/${subnetName}'

var publicIpAddressName = 'pip-azfw'

var logCategories = [
  { name: 'AzureFirewallApplicationRule' }
  { name: 'AzureFirewallNetworkRule' }
  { name: 'AzureFirewallDnsProxy' }
  { name: 'AZFWNetworkRule' }
  { name: 'AZFWApplicationRule' }
  { name: 'AZFWNatRule' }
  { name: 'AZFWThreatIntel' }
  { name: 'AZFWIdpsSignature' }
  { name: 'AZFWDnsQuery' }
  { name: 'AZFWFqdnResolveFailure' }
  { name: 'AZFWFatFlow' }
  { name: 'AZFWApplicationRuleAggregation' }
  { name: 'AZFWNetworkRuleAggregation' }
  { name: 'AZFWNatRuleAggregation' }
]

var ipConfig = [
  {
    name: format('{0}-{1}', take('${deployment().name}', 53), 'ipconf')
    properties: {
      publicIPAddress: {
        id: pip.outputs.publicIpResourceId
      }
      subnet: ((isSecuredHubFirewall) == true) ? json('null') : {
        id: azureFirewallSubnetId
      }
    }
  }
]

/* resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnetName
}

var azFwSubnetId = '${vnet.id}/subnets/${subnetName}' */

module pip 'publicIp.bicep' = {
  name: format('{0}-{1}', take('${deployment().name}', 53), 'pip-azfw')
  params: {
    location: location
    zones: [ 1, 2, 3 ]
    publicIPAddressName: '${publicIpAddressName}-01'
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    publicIPIdleTimeoutInMinutes: 4
    sku: {
      name: 'Standard'
    }
  }
}

resource AzureFW 'Microsoft.Network/azureFirewalls@2022-01-01' = {
  name: AzureFWname
  location: location
  zones: ((length(availabilityZones) == 0) ? json('null') : availabilityZones)
  properties: {
    sku: {
      name: ((isSecuredHubFirewall) == true) ? ('AZFW_Hub') : ('AZFW_VNet')
      tier: 'Standard'
    }
    applicationRuleCollections: ((isSecuredHubFirewall) == true) ? json('null') : applicationRuleCollections
    networkRuleCollections: ((isSecuredHubFirewall) == true) ? json('null') : networkRuleCollections
    natRuleCollections: natRuleCollections
    threatIntelMode: ((isSecuredHubFirewall) == true) ? json('null') : threatIntelMode
    ipConfigurations: ((isSecuredHubFirewall) == true) ? json('null') : ipConfig
    firewallPolicy: ((isSecuredHubFirewall) == false) ? json('null') : {
      id: firewallPolicyId
    }
    virtualHub: ((isSecuredHubFirewall) == false) ? json('null') : {
      id: hubId
    }
    hubIPAddresses: ((isSecuredHubFirewall) == false) ? json('null') : {
      publicIPs: {
        addresses: [
          {
            address: pip.outputs.publicIpResourceId
          }
        ]
        count: 1
      }
    }
  }
}

resource diagnostics 'microsoft.insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  scope: AzureFW
  name: 'diag-${AzureFWname}'
  properties: {
    workspaceId: empty(logAnalyticsWorkspaceId) ? null : logAnalyticsWorkspaceId
    storageAccountId: empty(diagnosticStorageAccountId) ? null : diagnosticStorageAccountId
    logs: [for category in logCategories: {
      category: category.name
      enabled: true
    }]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output resourceId string = AzureFW.id
