<#
    Script to test the PowerShell script New-LogicAppDoc.ps1 using a json file with the Logic App Workflow configuration
#>

param(
    [Parameter(Mandatory=$true)]
    [string]
    $SubscriptionId, 

    [Parameter(Mandatory=$true)]
    [string]
    $ResourceGroupName, 

    [Parameter(Mandatory=$false)]
    [string]
    $LogicAppName,

    [Parameter(Mandatory=$false)]
    [string]
    $WorkingDirectory,

    [Parameter(Mandatory = $true,
    ParameterSetName = 'Local')]
    [string]$Location,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Get-Location).Path,

    [Parameter(Mandatory = $false,
    ParameterSetName = 'Local')]
    [string]$FilePath,    

    [Parameter(Mandatory = $false)]
    [boolean]$ConvertToADOMarkdown = $false,
    
    [Parameter(Mandatory = $false)]
    [bool] $replaceU0027 = $false,
    
    [Parameter(Mandatory = $false)]
    [bool]$Show = $false    
)

#region Import PowerShell Modules. Add more modules if needed
if (Get-Module -ListAvailable -Name PSDocs) {
    Write-Verbose -Message 'PowerShell Module PSDocs is already installed'
}
else {
    Write-Verbose 'Installing PowerShell Module PSDocs'
    Install-Module PSDocs -RequiredVersion 0.9.0 -Scope CurrentUser -Repository PSGallery -SkipPublisherCheck -Confirm:$false -Force | Out-Null
}
#endregion

#region dot source Helper Functions
. (Join-Path $PSScriptRoot 'Helper.ps1')
#endregion

#region Set Variables
$templateName = 'Azure-LogicApp-Documentation'
$templatePath = (Join-Path $PSScriptRoot 'LogicApp.Doc.ps1')
$templateStandardName = 'Azure-Standard-LogicApp-Documentation'
$templateStandardPath = (Join-Path $PSScriptRoot 'LogicApp.Cover.Doc.ps1')
#$SubscriptionId = 'Unknown'
#$SubscriptionName = 'Unknown'
#$ResourceGroupName = 'Unknown'
#$LogicAppName = 'Unknown'
#endregion


@'
 _                _         _                ____
| |    ___   __ _(_) ___   / \   _ __  _ __ |  _ \  ___   ___ ___
| |   / _ \ / _` | |/ __| / _ \ | '_ \| '_ \| | | |/ _ \ / __/ __|
| |__| (_) | (_| | | (__ / ___ \| |_) | |_) | |_| | (_) | (__\__ \
|_____\___/ \__, |_|\___/_/   \_\ .__/| .__/|____/ \___/ \___|___/
            |___/               |_|   |_|
                                                                                                                                                         
Author: Kelvin Smith
Modified from the codebase from: Stefan Stranger 
Github: https://github.com/gooseleggs/logicappdocs
Version: 2.0.0

'@.foreach({
        Write-Host $_ -ForegroundColor Magenta
    })
$global:shownLogo = $true
$connections = @()

#region Helper Functions

# From PowerShell module AzViz. (https://raw.githubusercontent.com/PrateekKumarSingh/AzViz/master/AzViz/src/private/Test-AzLogin.ps1)
Function Test-AzLogin {
    [CmdletBinding()]
    [OutputType([boolean])]
    [Alias()]
    Param()

    Begin {
    }
    Process {
        # Verify we are signed into an Azure account
        try {
            try {
                Import-Module Az.Accounts -Verbose:$false   
            }
            catch {}
            Write-Verbose 'Testing Azure login'
            $isLoggedIn = [bool](Get-AzContext -ErrorAction Stop)
            if (!$isLoggedIn) {                
                Write-Verbose 'Not logged into Azure. Initiate login now.'
                Write-Host 'Enter your credentials in the pop-up window' -ForegroundColor Yellow
                $isLoggedIn = Connect-AzAccount
            }
        }
        catch [System.Management.Automation.PSInvalidOperationException] {
            Write-Verbose 'Not logged into Azure. Initiate login now.'
            Write-Host 'Enter your credentials in the pop-up window' -ForegroundColor Yellow
            $isLoggedIn = Connect-AzAccount
        }
        catch {
            Throw $_.Exception.Message
        }
        [bool]$isLoggedIn
    }
    End {
        
    }
}
#endregion

# Given a list of files, delete folders that are not in the list
function Compare-And-Delete {
    param (
        [string]$SourceList,
        [string]$TargetDir
    )

    # Get the list of folders in the target directory
    $targetFolders = Get-ChildItem -Path $TargetDir -Directory

    # Compare and delete folders in the target directory that are not in the source directory
    foreach ($folder in $targetFolders) {
        if (-not $sourceFolderNames.ContainsKey($folder.Name)) {
            Remove-Item -Path $folder.FullName -Recurse -Force
            Write-Output "Deleted folder: $($folder.FullName)"
        }
    }
}

#region Get Logic App Workflow code
if (!($FilePath)) {

    Write-Host ('Getting Logic App Workflow code for Logic App "{0}" in Resource Group "{1}" and Subscription "{2}"' -f $LogicAppName, $ResourceGroupName, $(Get-AzContext).Subscription.Name) -ForegroundColor Green

    # Test if the user is logged in
    if (!(Test-AzLogin)) {
        break
    }

    $SubscriptionName = (Get-AzContext).Subscription.Name

    $files = "host.json", "connections.json", "parameters.json"

    # Create source directory if it does not exist
    if (!( Test-Path -Path "$WorkingDirectory/$name")) {
        write-host "Creating directory '$WorkingDirectory/$name'"
        New-Item -Path "$WorkingDirectory/$name" -Type Directory | Out-Null
    }

    # Download Files
    Write-Host "Downloading configuration files..."
    $files | ForEach-Object {
        Write-Output "  Downloading Config file $_"
        $hostFile = Invoke-AzRestMethod `
            -Uri "https://$LogicAppName.scm.azurewebsites.net/api/vfs/site/wwwroot/$_" `
            -ResourceId "https://management.azure.com/" 
        if ($hostFile.StatusCode -eq 200) {
            $writeFile = $true
            if (Test-Path -Path $workingDirectory/$_ -PathType leaf) {
                $file = (Get-Content $workingDirectory/$_ -Raw).Trim()
                $writeFile = !(Compare-FileChecksumOfStrings -sourceString ($hostFile.Content).Trim() -TargetString ($file ))
            }
            if ($writeFile) {
                Write-output "$file definition differs from local copy - updating"
                $hostFile.Content > "$WorkingDirectory/$_"
            }
        } else {
            Write-Output "Download failed for $_"
            Write-Output $hostFile.Content
            exit
        }
    }

    # Create a hash set of source folder names for quick lookup
    $sourceFolderNames = @{}

    $workflows = Invoke-AzRestMethod `
        -Path "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$LogicAppName/workflows?api-version=2018-11-01"
    $workflowsObject = $workflows.Content | ConvertFrom-Json
    Write-Host "Downloading workflows..."
    $workflowsObject.value | ForEach-Object {
        $name = $_.name -replace '.*/'
        Write-host "  Downloading definition for $name" -ForegroundColor Green
        $hostFile = Invoke-AzRestMethod `
            -Uri "https://$LogicAppName.scm.azurewebsites.net/api/vfs/site/wwwroot/$name/workflow.json" `
            -ResourceId "https://management.azure.com/" 

        $writeFile = $true
        if (Test-Path -Path $WorkingDirectory/$name/workflow.json -PathType leaf) {
            $writeFile = !(Compare-FileChecksumOfStrings -sourceString ($hostFile.Content).Trim() -TargetString (Get-Content $WorkingDirectory/$name/workflow.json -Raw).Trim())
        }
        if ($writeFile) {
            Write-output "$name Logic app is new or updated - writing"
            New-Item -Path "$WorkingDirectory/$name/workflow.json" -ItemType File -Force | Out-Null
            $hostFile.Content > "$WorkingDirectory/$name/workflow.json"
        }

        # Store a list of files that should be in the directory
        $fileList = @{ 'workflow.json' = $true; 'overview.md' = $true }
        # See if there are any PowerShell scripts

        $codeFileLines = $hostFile.Content | Where-Object { $_ -match '"CodeFile":' }
        $codeFileLines | ForEach-Object {
            if ($_ -match '"CodeFile":\s*"([^"]+)"') {
                $filename = $matches[1]
                $fileList[$filename] = $true
                Write-host "    Downloading PowerShell script for $name - $filename" -ForegroundColor Green
                $powerShellScript = Invoke-AzRestMethod `
                    -Uri "https://$LogicAppName.scm.azurewebsites.net/api/vfs/site/wwwroot/$name/$filename" `
                    -ResourceId "https://management.azure.com/"
                if ($powerShellScript.StatusCode -eq 200) {
                    $writeFile=$true
                    if (Test-Path -Path $WorkingDirectory/$name/$filename -PathType leaf) {
                        $writeFile = !(Compare-FileChecksumOfStrings -sourceString ($powerShellScript.Content).Trim() -TargetString (Get-Content $WorkingDirectory/$name/$filename -Raw).Trim())
                    }
                    if ($writeFile) {
                        Write-output "      $filename PowerShell differs from local copy - updating"
                        New-Item -Path "$WorkingDirectory/$name/$filename" -ItemType File -Force | Out-Null
                        $powerShellScript.Content > "$WorkingDirectory/$name/$filename"
                    }
                } else {
                    Write-host "    Error downloading PowerShell Script" -ForegroundColor Yellow
                }
            }
        }
        # Delete any items that should not be their
        # Get the list of folders in the target directory
        $targetFiles = Get-ChildItem -Path $workingDirectory/$name -File

        # Compare and delete files in the target directory that are not in the source directory
        foreach ($file in $targetFiles) {
            if ( -not $fileList.ContainsKey($file.Name)) {
                Remove-Item -Path $file.FullName -Force
                Write-Output "Deleted file: $($file.FullName)"
            }
        }

        $sourceFolderNames[$name] = $true
    }

    # Remove folders that we have not downloaded this time
    Compare-And-Delete -SourceList $sourceFolderNames -TargetDir $WorkingDirectory

    # Write out a definition file in case we read it back
    "{`"SubscriptionID`": `"$SubscriptionId`", `"SubscriptionName`": `"$SubscriptionName`",`"ResourceGroupName`": `"$ResourceGroupName`",`"LogicAppName`": `"$LogicAppName`"}" | ConvertFrom-Json | ConvertTo-JSON > "$WorkingDirectory/logicApp.json"

    # Lets see if the defintion file exists
    $LAconnections = @{}
    if (Test-Path -Path "$WorkingDirectory/connections.json" -PathType Leaf) {

        write-host "Getting Connection information"
        # If it does...read in the variables and continue
        $json = Get-Content -Path "$WorkingDirectory/connections.json" | ConvertFrom-JSON

            # serviceProviderConnections
            Write-Host "Processing Service Provider Connections" 
            $LAconnections['serviceProviderConnections'] = @()
            $json.serviceProviderConnections | Get-Member -MemberType NoteProperty | ForEach-Object {
                $key = $_.Name
    #            write-Host $key
                Write-host "  Processing $key Service Provider connection" -ForegroundColor Green
                $json.serviceProviderConnections.$key | ForEach-Object {
      
                    $LAconnections['serviceProviderConnections'] += [PSCustomObject]@{
                        DisplayName = $_.displayName
                        Name = $key
                        Parameters = $_.parameterValues | ConvertTo-JSON
                        ServiceProvider = $_.serviceProvider
                    }               
                }
            }

        # Process FunctionConnections
        write-host "Getting Function Connection information"
        $LAconnections['functionConnections'] = @()
        $json.functionConnections | Get-Member -MemberType NoteProperty | ForEach-Object {
            $key = $_.Name
    #        write-Host $key
            Write-host "  Retrieving $key managed connection" -ForegroundColor Green

            $functionID = $json.functionConnections.$key.function.id

            $uri = "https://management.azure.com$($functionId)?api-version=2020-06-01"
            $functionDetails = Invoke-AzRestMethod -Uri $uri
            # Convert response to object
            $content = $functionDetails.Content | ConvertFrom-Json

            if ($functionDetails.StatusCode -eq 200 ) {    
                $LAconnections['functionConnections'] += [PSCustomObject]@{
                    DisplayName = $content.properties.name
                    Name = $key
                    Language = $content.properties.language
                    Type = $content.type
                    Location = $content.location
                }
            } else {
                Write-host "    Issue retrieving connection details."
                $LAconnections['functionConnections'] += [PSCustomObject]@{
                    DisplayName = $content.properties.name
                    Name = $key
                    Status = 'Error'
                    State = $content.error.code
                    Parameters = $content.error.message
                }            
            }
        }

        # Process ManagedAPIConnections
        $LAconnections['managedApiConnections'] = @()
        write-host "Getting Managed API Connection information"
        $json.managedApiConnections | Get-Member -MemberType NoteProperty | ForEach-Object {
            $key = $_.Name
            Write-host "  Retrieving $key managed connection" -ForegroundColor Green
            $connectionId = $json.managedApiConnections."$key".connection.id
            #[PSCustomObject]@{Key = $key; Value = $json.managedApiConnections."$key"}
            $uri = "https://management.azure.com$($connectionId)?api-version=2018-07-01-preview"
            $connectionDetails = Invoke-AzRestMethod -Uri $uri
            # Convert response to object
            $content = $connectionDetails.Content | ConvertFrom-Json

            if ($connectionDetails.StatusCode -eq 200 ) {    
                $LAconnections['managedApiConnections'] += [PSCustomObject]@{
                    DisplayName = $content.properties.displayName
                    Name = $key
                    Status = $content.properties.overallStatus
                    State = $content.properties.connectionState
                    Parameters = $content.properties.parameterValueSet | ConvertTo-Json
                    Type = $content.properties.api.displayName
                    Location = $content.location
                    Tags = $content.tags
                }

            } else {
                Write-host "    Issue retrieving connection details."
                $LAconnections['managedApiConnections'] += [PSCustomObject]@{
                    DisplayName = $content.properties.displayName
                    Name = $key
                    Status = 'Error'
                    State = $content.error.code
                    Parameters = $content.error.message
                    Type = ''
                    Location = ''
                    Tags = ''
                }            
            }
        }

        # Output to working directory
        $LAconnections | ConvertTo-JSON | Out-File -FilePath "$WorkingDirectory/resolved_connections.json"

    } else {
        # ... else ah oh - time to quit  
        Write-Host 'Cannot find connections.json' -ForegroundColor Yellow
    }

    Write-Host "Finished Downloading"

} else {
    # Say that we are using a working directory
    Write-Output -InputObject ('Using Logic App Workflow code from Folder "{0}"' -f $FilePath)

    # Standardize on WorkingDirectory variable
    $WorkingDirectory = $FilePath

    if (Test-path -Path "$workingDirectory/resolved_connections.json") {
        $LAconnections = Get-Content -Path "$workingDirectory/resolved_connections.json" | ConvertFrom-JSON
    }
}

# Now we have (hopefully) a populated folder, lets get down to work

# Lets see if the defintion file exists
if (Test-Path -Path "$WorkingDirectory/logicApp.json" -PathType Leaf) {

    # If it does...read in the variables and continue
    $json = Get-Content -Path "$WorkingDirectory/logicApp.json" | ConvertFrom-JSON

    # Set the variables
    $SubscriptionId = $json.SubscriptionID
    $SubscriptionName = $json.SubscriptionName
    $ResourceGroupName = $json.ResourceGroupName
    $LogicAppName = $json.LogicAppName
} else {
    # ... else ah oh - time to quit
    Write-Host 'Cannot find logicApp.json - quitting' -ForegroundColor Yellow
    exit
 }

# Lets see if the parameters file exists
if (Test-Path -Path "$WorkingDirectory/parameters.json" -PathType Leaf) {

    # If it does...read in the variables and continue
    $LAParameters = Get-Content -Path "$WorkingDirectory/parameters.json" -Raw| ConvertFrom-JSON
    # Convert the hashtable to a custom object and then to a table  
    $LAParameters = $LAParameters.PSObject.Properties | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            Type      = $_.Value.type
            Value     = $_.Value.value
        }
    }
} else {
    # ... else ah oh - time to quit
    Write-Host 'Cannot find parameters.json - quitting' -ForegroundColor Yellow
    exit
}    

#endregion


$workflows = Get-ChildItem -Path  "$WorkingDirectory" -Directory | Select-Object Name, LastWriteTime

# Get all subfolders
$subfolders = Get-ChildItem -Path $WorkingDirectory -Directory

# Initialize an array to store the results
$workflows = @()

# Loop through each subfolder
foreach ($folder in $subfolders) {
    # Define the path to the workflow.json file
    $workflowFilePath = Join-Path -Path $folder.FullName -ChildPath "workflow.json"
    
    # Check if the workflow.json file exists
    if (Test-Path -Path $workflowFilePath) {
        # Get the modification date of the workflow.json file
        $modificationDate = (Get-Item -Path $workflowFilePath).LastWriteTime
        
        # Create a PSCustomObject with the folder name and modification date
        $workflow = [PSCustomObject]@{
            Name            = $folder.Name
            LastWriteTime   = $modificationDate
        }
        
        # Add the result to the array
        $workflows += $workflow
    }
}

# Ensure that the output directory exists
if (! (Test-Path -Path $outputPath -PathType Container)) {
    New-Item -Path $outputPath -ItemType Directory -Force
}

$OutputPath = "$OutputPath\$LogicAppName"

# Temporary store path as we need to reset it after each invocation of New-LogicAppDoc
$basePath = $OutputPath

# Temporary variable as $logicAppName updated during dot sourcing 
$LogicAppNameStored = $LogicAppName


# Iterate over all directory paths and create output for workflows
 Get-ChildItem -Path "$WorkingDirectory" -Directory | 
 Foreach-Object {
     $wfName =  $_.Name

     $params = @{
         SubscriptionName       = $SubscriptionName
         ResourceGroupName      = $ResourceGroupName
         Location               = $Location
         FilePath               = "$WorkingDirectory/$wfName/workflow.json"
         LogicAppName           = $wfName
         OutputPath             = "$outputPath\$wfName.md"
         Verbose                = $false
         Debug                  = $false
         ConvertToADOMarkdown   = $false
         Show                   = $false
         replaceU0027           = $true
     }

     write-Host "==================================================="
     Write-host "Processing $WorkingDirectory/$wfName/workflow.json"
     write-Host "==================================================="
     . ..\src\New-LogicAppDoc.ps1 @params

    # Reset the path
    $OutputPath = $basePath
 }


write-Host "==================================================="
Write-host "Creating Readme document"

$overview = ''
if (Test-Path -Path "$WorkingDirectory/Overview.md" ) {
   write-host "    Found Overview.md"
   $overview = Get-Content "$WorkingDirectory/Overview.md" -Raw
}

write-Host "==================================================="

# Create an Index document
#region Generate Cover Markdown documentation for Standard Logic App Workflow
$InputObject = [pscustomobject]@{
    'LogicApp'       = [PSCustomObject]@{
        Name              = $LogicAppNameStored
        ResourceGroupName = $resourceGroupName
        Location          = $Location
        SubscriptionName  = $SubscriptionName
        Parameters        = $LAParameters
        Workflows         = $workflows
        Connections       = $LAConnections
        Overview          = $overview
    }
}

$options = New-PSDocumentOption -Option @{ 'Markdown.UseEdgePipes' = 'Always'; 'Markdown.ColumnPadding' = 'Single' };
$null = [PSDocs.Configuration.PSDocumentOption]$Options
$invokePSDocumentSplat = @{
    Path         = $templateStandardPath
    Name         = $templateStandardName
    InputObject  = $InputObject
    Culture      = 'en-us'
    Option       = $options
    InstanceName = $LogicAppNameStored
}

$markDownFile = Invoke-PSDocument @invokePSDocumentSplat
$markDownFile | set-content -path "$outputPath/README.md" -force -NoNewline -Encoding ASCII

$global:shownLogo = $false