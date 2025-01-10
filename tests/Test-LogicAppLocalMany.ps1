<#
    Script to test the PowerShell script New-LogicAppDoc.ps1 using a json file with the Logic App Workflow configuration
#>

Get-ChildItem "..\examples\*.json" -Filter *.json | 
Foreach-Object {
  $fullName =  $_.FullName
  $basename = $_.BaseName

    $params = @{
        SubscriptionName = 'N/A'
        ResourceGroupName = 'N/A'
        Location         = 'N/A'
        FilePath         = $fullName
        LogicAppName     = "$basename"
        OutputPath       = "..\examples\uc\$basename.md"
        Verbose          = $false
        Debug            = $false
        ConvertToADOMarkdown = $false
        Show             = $false
        replaceU0027        = $true
    }

    write-Host "==================================================="
    Write-host "Processing $basename"
    write-Host "==================================================="
    . ..\src\New-LogicAppDoc.ps1 @params
}
