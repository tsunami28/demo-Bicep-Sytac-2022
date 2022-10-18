//New-AzResourceGroupDeployment -ResourceGroupName demo-sytac-2022 -TemplateFile <path-to-bicep>
//az monitor diagnostic-settings categories list --resource 'FirewallResourceId' -otsv --query 'value[*].[name]'

//Predeploy:
  //RG
  //VNET
  //Firewall takes ~6min

//Create Log Analitics workspace
// name: format('{0}-{1}', take('${deployment().name}', 53), 'laws')
//Exctract parameter as proposed


//Create Azure Firewall
//Exctract projectName parameter
//String functions vs interpolation
//Show hidden parameters
