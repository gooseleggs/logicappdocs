<#
    Script to test the PowerShell script New-LogicAppDoc.ps1 using a json file with the Logic App Workflow configuration
#>

$params = @{
    SubscriptionName = 'Visual Studio Enterprise'
    ResourceGroupName = 'jiraintegration-demo-rg'
    Location         = 'westeurope'
    FilePath         = '..\examples\Azure-Kelvin-LogicApp.json'
    LogicAppName     = 'logic-jiraintegration-demo'
    OutputPath       = '..\examples\Azure-Kelvin-LogicApp.md'
    Verbose          = $false
    Debug            = $false
    ConvertToADOMarkdown = $false
    Show             = $false
}

. ..\src\New-LogicAppDoc.ps1 @params