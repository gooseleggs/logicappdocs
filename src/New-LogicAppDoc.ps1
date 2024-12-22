[CmdletBinding(DefaultParameterSetName = 'Azure')]
Param(
    [Parameter(Mandatory = $true,
        ParameterSetName = 'Azure')]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true,
        ParameterSetName = 'Local')]
    [string]$SubscriptionName,

    [Parameter(Mandatory = $true,
        ParameterSetName = 'Local')]
    [string]$Location,

    [Parameter(Mandatory = $true,
        ParameterSetName = 'Local')]
    [string]$FilePath,

    [Parameter(Mandatory = $true)]
    [string]$LogicAppName,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [boolean]$ConvertToADOMarkdown = $false,

    [Parameter(Mandatory = $false)]
    [bool] $replaceU0027 = $false,

    [Parameter(Mandatory = $false)]
    [bool]$Show = $false
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'


@"
██╗      ██████╗  ██████╗ ██╗ ██████╗ █████╗ ██████╗ ██████╗ ██████╗  ██████╗  ██████╗███████╗
██║     ██╔═══██╗██╔════╝ ██║██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔═══██╗██╔════╝██╔════╝
██║     ██║   ██║██║  ███╗██║██║     ███████║██████╔╝██████╔╝██║  ██║██║   ██║██║     ███████╗
██║     ██║   ██║██║   ██║██║██║     ██╔══██║██╔═══╝ ██╔═══╝ ██║  ██║██║   ██║██║     ╚════██║
███████╗╚██████╔╝╚██████╔╝██║╚██████╗██║  ██║██║     ██║     ██████╔╝╚██████╔╝╚██████╗███████║
╚══════╝ ╚═════╝  ╚═════╝ ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝     ╚═════╝  ╚═════╝  ╚═════╝╚══════╝
                                                                                                                                                         
Author: Stefan Stranger
Github: https://github.com/stefanstranger/logicappdocs
Version: 1.1.5

"@.foreach({
        Write-Host $_ -ForegroundColor Magenta
    })

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
#endregion

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

#region Get Logic App Workflow code
if (!($FilePath)) {

    # Test if the user is logged in
    if (!(Test-AzLogin)) {
        break
    }

    $SubscriptionName = (Get-AzContext).Subscription.Name    

    Write-Host ('Getting Logic App Workflow code for Logic App "{0}" in Resource Group "{1}" and Subscription "{2}"' -f $LogicAppName, $ResourceGroupName, $(Get-AzContext).Subscription.Name) -ForegroundColor Green

    $accessToken = Get-AzAccessToken -ResourceUrl 'https://management.core.windows.net/'
    $headers = @{
        'authorization' = "Bearer $($AccessToken.token)"
    }

    $apiVersion = "2016-06-01"
    $uri = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($resourceGroupName)/providers/Microsoft.Logic/workflows/$($logicAppName)?api-version=$($apiVersion)"
    $LogicApp = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
    #endregion

    $Location = $LogicApp.location

    $Objects = Get-Action -Actions $($LogicApp.properties.definition.actions)

    # Get Logic App Connections
    if ($LogicApp.properties.parameters | Get-Member -MemberType NoteProperty -Name '$connections') {
        $Connections = Get-Connection -Connection $($LogicApp.properties.parameters.'$connections'.value)
    }
    else {
        $Connections = $null
    }
}
else {
    Write-Output -InputObject ('Using Logic App Workflow code from file "{0}"' -f $FilePath)
    $LogicApp = Get-Content -Path $FilePath | ConvertFrom-Json

    $Objects = Get-Action -Actions $($LogicApp.definition.actions)

    # Get Logic App Connections
    if ($LogicApp | Get-Member -MemberType NoteProperty -Name 'parameters') {
        if ($LogicApp.parameters | Get-Member -MemberType NoteProperty -Name '$connections') {
            $Connections = Get-Connection -Connection $($LogicApp.parameters.'$connections'.value)
        }
        else {
            $Connections = $null
        }
    }
    else {
        $Connections = $null
    }
}

# Ensure that there is an array of objects!
if ($objects -isnot [system.array]) { $objects = @($objects)}

if ($VerbosePreference -eq 'Continue') {
    Write-Verbose -Message ('Found {0} actions in Logic App' -f $Objects.Count)
    Write-Verbose ($objects | Format-Table | out-string)
}

# Create the Mermaid code
Write-Host ('Creating Mermaid Diagram for Logic App') -ForegroundColor Green

$mermaidCode = "graph TB" + [Environment]::NewLine
$mermaidCode += "    Trigger" + [Environment]::NewLine

#$inIf = 0
$ifCache = @{}
# Group actions by parent property
$objects | Group-Object -Property Parent | ForEach-Object {
    $subgraphDisplayName = ''
    $blockCode = ''
    if (![string]::IsNullOrEmpty($_.Name)) {
        $subgraphName = $_.Name
        if ($subgraphName.EndsWith("-True")) { $subgraphDisplayName = ' [True&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;]'}
        if ($subgraphName.EndsWith("-False")) { $subgraphDisplayName = ' [False&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;]'}
        $blockCode += "    subgraph $subgraphName$subgraphDisplayName" + [Environment]::NewLine
        $blockCode += "    direction TB" + [Environment]::NewLine
        # Add children action nodes to subgraph
        foreach ($index in $_.Group) {
            $displayName=''
            $childAction = $index.ActionName
            if ( $index.type -eq 'If') {
                write-host "***************** $childAction is a $($index.type)"
                $blockCode += "      subgraph $childAction$($displayName)If [ ]" + [Environment]::NewLine
                $blockCode += "      direction TB" + [Environment]::NewLine
                $blockCode += "        $childAction$displayName{$childAction}" + [Environment]::NewLine
                $blockCode += "!{$childAction}" + [Environment]::NewLine
                $blockCode += "      end" + [Environment]::NewLine
#                $inIf ++
                $displayName = "{$childAction}"
            } else {
                $blockCode += "        $childAction$displayName" + [Environment]::NewLine
            }
        }
#        $inIf--
#        if (!$inIf) { $blockCode += "    end" + [Environment]::NewLine }
        $blockCode += "    end" + [Environment]::NewLine
        if (![string]::IsNullOrEmpty($subgraphDisplayName)) {
            write-host "Writing $subgraphName to cache"
            $ifName = $subgraphName -replace '(-False|-True)', ''
            if ($ifCache[$ifName]) {
                $ifCache[$ifName].Code += $blockCode
            } else {
                $ifCache[$ifName] += @{code = $blockCode; found = $false}
            }
        } else {
            $mermaidCode += $blockCode
        }

    }
    else {}        
}

# Add any If blocks that do not have a parent
$objects | Where-Object { $_.Type -eq 'If' -and $_.Parent -eq $null } | ForEach-Object {
    $actionName = $_.ActionName
    $mermaidCode += "    subgraph $($actionName)If [ ]" + [Environment]::NewLine
    $mermaidCode += "    direction TB" + [Environment]::NewLine
    $mermaidCode += "      $actionName{$actionName}" + [Environment]::NewLine
    $mermaidCode += "!{$actionName}" + [Environment]::NewLine
    $mermaidCode += "    end" + [Environment]::NewLine
}

# Iterate over the cache until cache is emptied replacing placeholders with code
if ($ifCache.count) {
    for ($loopCount = 1; $loopCount -le $ifCache.count; $loopCount++) {
        $breakEarly = 1
        # Iterate through all the if block cache
        foreach ($cacheObject in $ifCache.GetEnumerator()) {
            # Can we find the placeholder value in mermaidCode...
            if ($mermaidCode | Select-String -Pattern "!{$($cacheObject.Name)}") {
                # ... yes...so replace the placeholder with the actual block
                Write-debug "$($cacheObject.Name): $($cacheObject.Value.code)"
                $mermaidCode = $mermaidCode.replace("!{$($cacheObject.Name)}", $($cacheObject.Value.code))
                # Signal that we have used this block
                $ifCache[$cacheObject.Name].found = $true
            } else {
                # Not found, so signal that we cannot break early
                if (!($cacheObject.Value.found)) {
                    write-debug "$($cacheObject.Name) is not in mermaid Definition"
                    $breakEarly = 0
                }
            }         
        }
        # If the breakEarly flag is still set, then we have added all the blocks that we can, so exit loop early
        if ($breakEarly) {
            break
        }
    }
}

# Iterate over the array again, to add in any that was missed for whatever reason (should not happen)
foreach ($cacheObject in $ifCache.GetEnumerator()) {
    if (!($cacheObject.Value.Found)) {
        $mermaidCode += $cacheObject.Value.code
    }
}

# Create links between runafter and actionname properties
foreach ($object in $objects) {
    if ($object | Get-Member -MemberType NoteProperty -Name 'RunAfter') {
        # If this is a scope object, skip otherwise we end up with a pointer back to outselves
#        if ($object.Type -eq 'Scope') { continue }

        # If this is a scope record, then dont point to it, but the actions past it
        if ($object.Type -eq 'Scope') {
            # If there are objects past this...
            if ($objects | Where-Object { $_.RunAfter -eq $object.ActionName -and $_.Parent -eq $object.ActionName }) {
                foreach ($scopeObject in $objects | Where-Object { $_.RunAfter -eq $object.ActionName -and $_.Parent -eq $object.ActionName }) {
                    $mermaidCode += "    $($object.RunAfter) --> $($scopeObject.ActionName)" + [Environment]::NewLine
                }
            } else {
                $mermaidCode += "    $($object.RunAfter) --> $($Object.ActionName)" + [Environment]::NewLine
            }
            continue
        } else {
            # If the RHS object is a scope object, then ignore it
            if ($objects | Where-Object { $_.Type -eq 'Scope' -and $_.ActionName -eq $object.RunAfter } ) {
                    continue
            }
        }

        # If this is a branch coming from an If statement
        if ($objects | Where-Object { $_.Type -eq 'If' -and $_.ActionName -eq $object.RunAfter } ) {
            # IF this is not a True or False branch, ie it is the next action...
            if ($object.RunAfter -eq ($object.Parent -replace '(-False|-True)', '')) {
                $mermaidCode += "    $($object.RunAfter) --> $($Object.ActionName)" + [Environment]::NewLine
                
            } else {
                # ... Point it to the subgraph of the If, and not the If decision box
                $mermaidCode += "    $($object.RunAfter)If --> $($Object.ActionName)" + [Environment]::NewLine
            }
            continue
        }

        # Check if the runafter property is not empty
        if (![string]::IsNullOrEmpty($object.RunAfter)) { 
            if (($object.runAfter | Measure-Object).count -eq 1) {
                $mermaidCode += "    $($object.RunAfter) --> $($object.ActionName)" + [Environment]::NewLine
            }
            else {
                foreach ($runAfter in $object.RunAfter) {
                    $mermaidCode += "    $runAfter --> $($object.ActionName)" + [Environment]::NewLine
                }
            }
        }
    }        
}

# Create link between trigger and first action
$firstActionLink = ($objects | Where-Object { $_.Runafter -eq $null }).ActionName
$mermaidCode += "    Trigger --> $firstActionLink" + [Environment]::NewLine

# Create the Call-out graph
Write-Host ('Creating Mermaid Call-Out Diagram for Logic App') -ForegroundColor Green

$calloutGraph = ''
$objects | Group-Object -Property Type | ForEach-Object {
    # Skip types that are internal
    if (! ($($_.name) -in 'Foreach','If','Compose', 'ParseJson', 'Response','InitializeVariable','until','SetVariable','Terminate','Query','Scope','Select')) {
        $name = $_.Name
        $calloutGraph += "    $name" + [Environment]::NewLine
        foreach ($childAction in $_.Group) {
            $value = $childAction.Value
            if ($name -eq 'Http') {
                $guid = New-Guid
                $value = $value.SubString(0, [math]::min($value.IndexOf("?"),$value.length))
                $calloutGraph += "      $guid$ (`"$value`")"  + [Environment]::NewLine
            } else {
                if ($value -eq '') { $value = $childAction.ActionName}
                $calloutGraph += "      $value" + [Environment]::NewLine
            }
        }
    }
}

# Generate chart
$mermaidCallout = ''
if ($calloutGraph -ne '') {
    $mermaidCallout = "mindmap" + [Environment]::NewLine
    $mermaidCallout += "  root($LogicAppName)" + [Environment]::NewLine
    $mermaidCallout += $calloutGraph
}
Write-Verbose ($mermaidCallout)

Write-Host ('Finished creating Mermaid Call-Out Diagram for Logic App') -ForegroundColor Green

# Sort-Action -Actions $objects

if ($VerbosePreference -eq 'Continue') {
    Write-Verbose -Message ('Found {0} actions in Logic App' -f $Objects.Count)
    Write-Verbose ($objects | Select-Object -Property ActionName, RunAfter, Type, Parent, Order | Sort-Object -Property Order | Format-Table | Out-String)
}

#region Generate Markdown documentation for Logic App Workflow
$InputObject = [pscustomobject]@{
    'LogicApp'       = [PSCustomObject]@{
        Name              = $LogicAppName
        ResourceGroupName = $resourceGroupName
        Location          = $Location
        SubscriptionName  = $SubscriptionName

    }
    'Actions'        = $objects
    'Connections'    = $Connections
    'Diagram'        = $mermaidCode
    'CalloutDiagram' = $mermaidCallout
}

$options = New-PSDocumentOption -Option @{ 'Markdown.UseEdgePipes' = 'Always'; 'Markdown.ColumnPadding' = 'Single' };
$null = [PSDocs.Configuration.PSDocumentOption]$Options
$invokePSDocumentSplat = @{
    Path         = $templatePath
    Name         = $templateName
    InputObject  = $InputObject
    Culture      = 'en-us'
    Option       = $options
    OutputPath   = $OutputPath
    InstanceName = $LogicAppName
}
$markDownFile = Invoke-PSDocument @invokePSDocumentSplat
$outputFile = $($markDownFile.FullName)
# If file contains space remove the spaces and rename file
if ($outputFile -match '\s') {
    $newOutputFile = $outputFile -replace '\s', '_'
    if (Test-Path -Path $newOutputFile) {
        Remove-Item -Path $newOutputFile -Force
    }
    Rename-Item -Path $outputFile -NewName $newOutputFile -Force
    $outputFile = $newOutputFile
}
Write-Host ('LogicApp Flow Markdown document is being created at {0}' -f $outputFile) -ForegroundColor Green
#endregion


#region replace \u0027 with ' in Markdown documentation for Logic App Workflow
if($replaceU0027){
    $pathToDocumentationFile = $outputFile
    $documentationFileData = Get-Content -Path $pathToDocumentationFile 
    $documentationFileData -replace '\\u0027' , "'" | set-content -path $pathToDocumentationFile 
}
#endregion

#region Convert Markdown to ADOMarkdown if ConvertTo-ADOMarkdown parameter is used
if ($ConvertToADOMarkdown) {
    # Run Bootstrap.ps1 to install mermaid-cli
    . (Join-Path $PSScriptRoot 'Bootstrap.ps1')
    Write-Host ('Converting Markdown to ADOMarkdown') -ForegroundColor Green
    $converttedOutputFile = ($outputFile -replace '.md$', '-ado.md')
    & { mmdc -i $outputFile  -o $converttedOutputFile -e png }
    Write-Host ('ADOMarkdown document is being created at {0}' -f $converttedOutputFile) -ForegroundColor Green
}

#region Open Markdown document if show parameter is used
if ($Show) {
    Write-Host ('Opening Markdown document in default Markdown viewer') -ForegroundColor Green
    if ($ConvertToADOMarkdown) {
        Start-Process -FilePath $converttedOutputFile
    }
    else {
        Start-Process -FilePath $outputFile
    }
}
#endregion