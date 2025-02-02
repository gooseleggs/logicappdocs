<#
    Helper script containing helper functions for the LogicAppDoc and PowerAutomateDoc PowerShell scripts.
#>

Function Get-Category {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        $action
    )

    $type = $action.type
    $value = ''
    $additional = $null
    switch ($action.type) {
        "ApiConnection" {
            # If this is a secret (or looks like a secret)
            if ( ($action.inputs.path).startsWith('/secrets/') ) {
                # Split the string by the / operator
                $secretsPath = $($action.inputs.path) -split "/"
                $secretsPath = $secretsPath[($secretsPath.count)-2] -split "'"
                $value = $secretsPath[1]
                $type = "Keystore"
            }
            if ( ($action.inputs.path).startsWith('/emails') ) {
                $type = "SendEmail"
                $value = ($action.inputs.body.recipients.to | select -expand address) -join ","
                $value = $value -replace "@","#commat;"
            }
            if ( ($action.inputs.path).startsWith('/v2/datasets') ) {
                $type = "SQL"
                # Lets dipose the SQL path into a tablular format
                $paths = $action.inputs.path -split "\('"
                $server = ($paths[1] -split "'\)")[0]
                $database = ($paths[2] -split "'\)")[0]
                $connRef = $action.inputs.host.connection.referenceName
                $sqlType = "Stored Proc"
                if ($paths[2] -match "/tables/") { $sqlType = 'Table'}
                $procTable = (($paths[3] -split "'\)")[0]) -replace "\[|\]",""
                $additional = [PSCustomObject]@{
                    Type      = $type
                    server    = $server
                    database  = $database
                    sqlType   = $sqlType
                    connRef   = $connRef
                    procTable = $procTable
                }
            }
        }
        "Function" {
            # Work out the function name by the URL
            if ($action.inputs.function | Get-Member -MemberType Noteproperty -Name 'id') {
                $value = $($action.inputs.function.id) -split "/"
                $value = $value[($value.count)-3]
            }
            $type = "Function"
        }
        "Workflow" {
             # Work out the workflow (logicApp) name by the URL
             $value = $($action.inputs.host.workflow.id) -split "/"
             $value = $value[($value.count)-1]

             # If this is a logic app...
             if ($($action.inputs.host.workflow.id) -match '.*Microsoft.Logic.*') {
                # ... make it show that
                $type = 'Logic App'
             }
        }
        "PowershellCode" {
            $value = $action.inputs.CodeFile
        }
        "Http" {
            # Work out the workflow (logicApp) name by the URL
             $value = $action.inputs.uri
             $value = $value.replace( "@{parameters('", "[")
             $value = $value.replace( "@{outputs('", "[")
             $value = $value.replace("')}","]")
             $value = $value.replace("//","#sol;#sol;")
             if ($value.indexOf('?') -gt 0) {
                $value = $value.SubString(0, $value.indexOf('?'))
             }
        }
        "ServiceProvider" {
            # If this is a keyvault blob
            if ($($action.inputs.serviceProviderConfiguration.serviceProviderId) -eq '/serviceProviders/keyVault') {
                $type = 'KeyVault'
                $value = $action.inputs.parameters.secretName
            }
        }
    }
    return @{type       = $type
             value      = $value
             additional = $additional
            }
}

Function Get-Action {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        $Actions,
        [Parameter(Mandatory = $false)]
        $Parent = $null
    )

    foreach ($key in $Actions.PSObject.Properties.Name) {
        $action = $Actions.$key
        $actionName = $key -replace '[ |(|)|@]', '_'
        Write-Verbose ('Action {0}' -f $actionName)
        Write-Verbose ('Object {0}' -f $($action | ConvertTo-Json -Depth 10 ))

        # new runafter code
        if ($action | Get-Member -MemberType Noteproperty -Name 'runafter') {
            $runAfter = if (![string]::IsNullOrWhitespace($action.runafter)) {            
                $action.runAfter.PSObject.Properties.Name -replace '[ |(|)|@]', '_'
            }
            elseif (([string]::IsNullOrWhitespace($action.runafter)) -and $Parent) {
                # if Runafter is empty but has parent use parent.
                $Parent -replace '(-False|-True)', ''
            }
            else {
                # if Runafter is empty and has no parent use null.
                $null
            }
        }
        else {
            Write-Warning ('Action {0} has no runafter property' -f $actionName)
            #Set runafter to parent if parent is not null
            if ($Parent) {
                $runAfter = $Parent  -replace '(-False|-True)', ''
            }
            else {
                $runAfter = $null
            }
        }     
        
        # Categorization of what component does
        $category = Get-Category -action $action 
        Write-Verbose ('Type {0}' -f $category.type)
        Write-Verbose ('Value {0}' -f $category.value)

        $inputs = if ($action | Get-Member -MemberType Noteproperty -Name 'inputs') { 
            $($action.inputs)
        } 
        else {
            # If there is an expression section, then likely an If statement
            if ($action | Get-Member -MemberType Noteproperty -Name 'expression') { 
                $($action.expression)
            } 
            else {
                # If there is a Foreach section, then likely a Foreach statement
                if ($action | Get-Member -MemberType Noteproperty -Name 'Foreach') { 
                    $($action.Foreach)
                } 
                else {
                    $null 
                }
            }
        }

        $type = $action.type

        # new ChildActions code
        $childActions = if (($action | Get-Member -MemberType Noteproperty -Name 'Actions') -and ($action.Actions.PSObject.Properties | measure-object).count -gt 0) { $action.Actions.PSObject.Properties.Name } else { $null }
        
        # Create PSCustomObject
        [PSCustomObject]@{
            ActionName   = $actionName
            RunAfter     = $runAfter
            Value        = $category.value
            Parent       = $Parent
            Type         = $category.type
            additional   = $category.additional
            ChildActions = $childActions
            Inputs       = if ($inputs) {
                Format-HTMLInputContent -Inputs $(Remove-Secrets -Inputs $($inputs | ConvertTo-Json -Depth 10 -Compress))
            }
            else {
                $null | ConvertTo-Json
            } # Output is a json string
        }

        if ($action.type -eq 'If') {
            # Check if the else property is present
            if ($action | Get-Member -MemberType Noteproperty -Name 'else') {
                # Get the actions for the true condition
                Write-Verbose -Message ('Processing action {0}' -f $actionName)
                # Check if Action has any actions for the true condition
                if (![string]::IsNullOrEmpty($action.actions)) { 
                    # Make sure there are actions to be done and not an empty list
                    if (![string]::IsNullOrEmpty($action.Actions)) {
                        Get-Action -Actions $($action.Actions) -Parent ('{0}-True' -f $actionName)
                    }
                    # Get the actions for the false condition
                    # Make sure there are actions to be done and not an empty list
                    if (![string]::IsNullOrEmpty($action.else.Actions)) {
                        Get-Action -Actions $($action.else.Actions) -Parent ('{0}-False' -f $actionName)
                    }
                }
            }
            #When there is only action for the true condition
            else {
                # Make sure there are actions to be done and not an empty list
                if (![string]::IsNullOrEmpty($action.Actions)) {
                    Get-Action -Actions $($action.Actions) -Parent ('{0}-True' -f $actionName)
                }
            }
        }

        # Recursively call the function for child actions
        elseif ($action | Get-Member -MemberType Noteproperty -Name 'Actions') {
            # Make sure there are actions to be done
            if (![string]::IsNullOrEmpty($action.Actions)) {
                Get-Action -Actions $($action.Actions) -Parent $actionName
            }
        }
    }   
}

Function Sort-Action {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        $Actions
    )

    # Turn input into an array. Otherwise count will not work.
    $Actions = @($Actions)

    # Search for the action that has an empty RunAfter property
    $firstAction = $Actions | Where-Object { [string]::IsNullOrEmpty($_.RunAfter) } |
    Add-Member -MemberType NoteProperty -Name Order -Value 0 -PassThru
    $currentAction = $firstAction

    # Define a variable to hold the current order index
    $indexNumber = 1

    #Loop through all the actions
    Write-Verbose -Message ('Sorting {0} Actions' -f $($Actions.Count))
    for ($i = 1; $i -lt $Actions.Count; $i++) {
        Write-Verbose -Message ('Processing currentaction {0} number {1} of {2} Actions in total' -f $($currentAction.ActionName), $i, $($Actions.Count))
        # Search for the action that has the first action's ActionName in the RunAfter property or the previous action's ActionName
        if (![string]::IsNullOrEmpty($firstAction)) {
            $Actions | Where-Object { $_.RunAfter -eq $firstAction.ActionName } | 
            Add-Member -MemberType NoteProperty -Name Order -Value $indexNumber
            $currentAction = ($Actions | Where-Object { $_.RunAfter -eq $firstAction.ActionName })
            # Set the firstAction variable to null
            $firstAction = $null            
            $indexNumber++ 
        }
        else {
            # Search for actions that have the previous action's ActionName in the RunAfter property
            # If there are multiple actions with the same RunAfter property, set the RunAfter property to the Parent property
            # Why does this logic changes the RunAfter property to the Parent property for the action getCompany Try? It should be getSecrets.
            # This is caused by the action get-atApiIntegrationCode that does not have an runafter property. This is la
            if (($Actions | Where-Object { $_.RunAfter -eq $($currentAction.ActionName) } | Measure-Object).count -gt 1) {
                $Actions | Where-Object { $_.RunAfter -eq $($currentAction.ActionName) } | ForEach-Object {                     
                    # Check if the action has a Parent Value
                    if (![string]::IsNullOrEmpty($_.Parent)) {
                        Write-Verbose -Message ('Setting RunAfter property {0} to Parent property value {1} for action {2}' -f $_.RunAfter, $_.Parent, $_.ActionName)
                        $_.RunAfter = $_.Parent
                    }
                    else {
                        Write-Verbose -Message ('Current action {0} with RunAfter property {1} has no Parent property' -f $_.ActionName, $_.RunAfter)
                    }
                }
                # Iterate first the condition status true actions.
                if ($Actions | Where-Object { $_.RunAfter -eq $(('{0}-True') -f $($currentAction.ActionName)) }) {
                    $Actions | Where-Object { $_.RunAfter -eq $(('{0}-True') -f $($currentAction.ActionName)) }  |
                    Add-Member -MemberType NoteProperty -Name Order -Value $indexNumber
                    $currentAction = $Actions | Where-Object { $_.RunAfter -eq $(('{0}-True') -f $($currentAction.ActionName)) }
                    # Increment the indexNumber
                    $indexNumber++
                }   
                else {
                    # Add Order property to the action that it's RunAfter property updated from the Parent property.
                    # This is the first action in a foreach loop.
                    # After this action the rest of rest of the foreach actions need to be processed.
                    if ($Actions | Where-Object { $_.RunAfter -eq $($currentAction.ActionName) -and ($null -ne $($_.Parent)) } ) {
                        $Actions | Where-Object { $_.RunAfter -eq $($currentAction.ActionName) -and ($null -ne $($_.Parent)) } |
                        Add-Member -MemberType NoteProperty -Name Order -Value $indexNumber 
                        $currentAction = $Actions | Where-Object { $_.RunAfter -eq $($currentAction.ActionName) -and ($null -ne $($_.Parent)) }
                        # Increment the indexNumber
                        $indexNumber++
                    }
                    else {
                        # There is another action with the same RunAfter property that runs parallel with the current action.
                        # Start with the first action that has the same RunAfter property.
                        if ($Actions | Where-Object { $_.RunAfter -eq $($currentAction.ActionName) }) {
                            $($Actions | Where-Object { $_.RunAfter -eq $($currentAction.ActionName) })[0] | 
                            Add-Member -MemberType NoteProperty -Name Order -Value $indexNumber 
                            # CurrentAction will be empty if the ???
                            $currentAction = $($Actions | Where-Object { $_.RunAfter -eq $($currentAction.ActionName) })[0]
                            # Increment the indexNumber
                            $indexNumber++                    
                        }
                    }                    
                }             
            }
            else {
                # If there cannot any action found with the previous action's ActionName in the RunAfter property, search for the action has a parent with the false condition.
                if ($Actions | Where-Object { $_.RunAfter -eq $($currentAction.ActionName) }) {
                    $Actions | Where-Object { $_.RunAfter -eq $($currentAction.ActionName) } | 
                    Add-Member -MemberType NoteProperty -Name Order -Value $indexNumber 
                    # CurrentAction will be empty if the ??
                    $currentAction = ($Actions | Where-Object { $_.RunAfter -eq $($currentAction.ActionName) })
                    # Increment the indexNumber
                    $indexNumber++                    
                }
                # Current error is that there can be an newly created action that does not have a parent property.???
                elseif (($null -ne $currentAction.Parent) -and ($Actions | Where-Object { $_.RunAfter -eq $(('{0}-False') -f $(($currentAction.Parent).Substring(0, [math]::max(1,($currentAction.Parent).length - 5)))) } )) {
                    $Actions | Where-Object { $_.RunAfter -eq $(('{0}-False') -f $(($currentAction.Parent).Substring(0, [math]::max(1,($currentAction.Parent).length - 5)))) }  |
                    Add-Member -MemberType NoteProperty -Name Order -Value $indexNumber 
                    # Fix the issue when currentAction is empty
                    if ($Actions | Where-Object { $_.RunAfter -eq $(('{0}-False') -f $(($currentAction.Parent).Substring(0, [math]::max(1,($currentAction.Parent).length - 5)))) }) {
                        $currentAction = $Actions | Where-Object { $_.RunAfter -eq $(('{0}-False') -f $(($currentAction.Parent).Substring(0, [math]::max(1,($currentAction.Parent).length - 5)))) }
                    }
                    # Increment the indexNumber
                    $indexNumber++
                }
                else {
                    # If there cannot any action found with the previous action's ActionName in the RunAfter property, search for the action has a parent with the same name as the currents action's runasfter property.
                    if ($Actions | Where-Object { $_.RunAfter -eq $($currentAction.Parent) -and !($_ | Get-Member -MemberType NoteProperty 'Order') }) {
                        $Actions | Where-Object { $_.RunAfter -eq $($currentAction.Parent) -and !($_ | Get-Member -MemberType NoteProperty 'Order') } | 
                        Add-Member -MemberType NoteProperty -Name Order -Value $indexNumber 
                        # CurrentAction will be empty if the ??
                        $currentAction = ($Actions | Where-Object { ($_ | Get-Member -MemberType NoteProperty 'Order') -and ($_.Order -eq $indexNumber) })
                        # Increment the indexNumber
                        $indexNumber++                    
                    }
                    else {
                        # When an action runs after a condition find orderid of last condition actionname.
                        # Fix issue when an async response is never used as a runafter property. Then use action that has same RunAfter propery as the current action.
                        if ($Actions | Where-Object { !($_ | Get-Member -MemberType NoteProperty 'Order') -and (![string]::IsNullOrEmpty($_.Parent)) }) {
                            # Check there is only one action, if not then use action that has same RunAfter propery as the current action.
                            if (@(($Actions | Where-Object { !($_ | Get-Member -MemberType NoteProperty 'Order') -and (![string]::IsNullOrEmpty($_.Parent)) })).count -eq 1) {
                                $Actions | Where-Object { !($_ | Get-Member -MemberType NoteProperty 'Order') -and (![string]::IsNullOrEmpty($_.Parent)) } | 
                                Add-Member -MemberType NoteProperty -Name Order -Value $indexNumber 
                                # CurrentAction
                                $currentAction = ($Actions | Where-Object { ($_ | Get-Member -MemberType NoteProperty 'Order') -and ($_.Order -eq $indexNumber) })
                                # Increment the indexNumber
                                $indexNumber++
                            }
                            elseif ($Actions | Where-Object { $_.RunAfter -eq $($currentAction.RunAfter) -and $_.ActionName -ne $currentAction.ActionName } ) {
                                $Actions | Where-Object { $_.RunAfter -eq $($currentAction.RunAfter) -and $_.ActionName -ne $currentAction.ActionName } |
                                Add-Member -MemberType NoteProperty -Name Order -Value $indexNumber
                                # CurrentAction
                                $currentAction = ($Actions | Where-Object { ($_ | Get-Member -MemberType NoteProperty 'Order') -and ($_.Order -eq $indexNumber) })
                                # Increment the indexNumber
                                $indexNumber++
                            }
                            # Move up one parent level and check if there is an action that has the same RunAfter property as the current action.
                            else {
                                # Get curentAction parent's parent. #Find Action with RunAfter value getSecrets
                                # Why does the action getCompany Try as a RunAfter property? It should be getSecrets.
                                # Steps when currentaction is not used as runafter property for any actions.
                                # 1. Get parent of currentAction Name (getSecrets)
                                # 2. Check for action with runafter of parent of currentaction. (does not exists)
                                # 3. Get grandparent of currentaction's parent (try)
                                # 4. If not found check for Action with no order property and runafter and and parent having value of grandparent.
                                # $parentCurrentAction = $currentAction.Parent
                                if (!($Actions | Where-Object { $_.RunAfter -eq $currentAction.Parent -and !$($_ | get-member -Name 'Order') })) {
                                    # Handle parent being True of false in name. Remove -True or -False from parent name.
                                    $currentparent = $($currentAction.Parent).Replace("-True", "").Replace("-False", "")
                                    $grandparent = ($Actions | Where-Object { $_.ActionName -eq $currentparent }).Parent
                                    if ($Actions | Where-Object { $_.RunAfter -eq $grandparent -and $_.Parent -eq $grandparent -and !$($_ | get-member -Name 'Order') }) {
                                        $Actions | Where-Object { $_.RunAfter -eq $grandparent -and $_.Parent -eq $grandparent -and !$($_ | get-member -Name 'Order') } |
                                        Add-Member -MemberType NoteProperty -Name Order -Value $indexNumber
                                        # CurrentAction
                                        $currentAction = ($Actions | Where-Object { ($_ | Get-Member -MemberType NoteProperty 'Order') -and ($_.Order -eq $indexNumber) })
                                        # Increment the indexNumber
                                        $indexNumber++
                                    }
                                    else {
                                        # Get overgrandparent of currentaction's parent.
                                        if (($Actions | Where-Object { $_.ActionName -eq $grandparent }).Parent) {
                                            $overgrandparent = ($Actions | Where-Object { $_.ActionName -eq $grandparent }).Parent
                                            $Actions | Where-Object { $_.RunAfter -eq $overgrandparent -and $_.Parent -eq $overgrandparent -and !$($_ | get-member -Name 'Order') } |
                                            Add-Member -MemberType NoteProperty -Name Order -Value $indexNumber
                                            # CurrentAction
                                            $currentAction = ($Actions | Where-Object { ($_ | Get-Member -MemberType NoteProperty 'Order') -and ($_.Order -eq $indexNumber) })
                                            # Increment the indexNumber
                                            $indexNumber++
                                        }
                                        else {
                                            $Actions | Where-Object { $_.RunAfter -eq $grandparent  -and !$($_ | get-member -Name 'Order') } |
                                            Add-Member -MemberType NoteProperty -Name Order -Value $indexNumber
                                            # CurrentAction
                                            $currentAction = ($Actions | Where-Object { ($_ | Get-Member -MemberType NoteProperty 'Order') -and ($_.Order -eq $indexNumber) })
                                            # Increment the indexNumber
                                            $indexNumber++
                                        }
                                        
                                    }

                                }
                            }                            
                        }
                    }
                }
            }                
        }
        Write-Verbose -Message ('Current action {0} with Order Id {1}' -f $($currentAction.ActionName), $($currentAction.Order) )
    }
}

Function Get-Connection {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        $Connection
    )

    foreach ($key in $Connection.PSObject.Properties) {
        [PSCustomObject]@{
            Name                 = $key.name
            ConnectionId         = $key.Value.connectionId
            ConnectionName       = $key.Value.connectionName
            ConnectionProperties = if ($key.Value | Get-Member -MemberType NoteProperty connectionProperties) { $key.Value.connectionProperties } else { $null }
            id                   = $key.Value.id
        } 
    }
}

Function Remove-Secrets {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        $Inputs
    )

    # Remove the secrets from the Logic App Inputs
    $regexPattern = '(\"headers":\{"Authorization":"(Bearer|Basic) )[^"]*'
    $Inputs -replace $regexPattern, '$1******'
}

# When the input contains a HTML input content, this needs to be wrapped within a <textarea disabled> and </textarea> tag.
Function Format-HTMLInputContent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        $Inputs
    )

    # If Input contains HTML input content, remove '\n characters and wrap the input within a <textarea disabled> and </textarea> tag.
    if ($Inputs -match '<html>') {
        Write-Verbose -Message ('Found HTML input content in Action Inputs')
        $($Inputs -replace '\\n', '') -replace '<html>', '<textarea disabled><html>' -replace '</html>', '</html></textarea>'
    }
    else {
        $Inputs
    }
}

Function Get-Trigger {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        $Triggers
    )

    $method = ""
    $schema = ""
    foreach ($key in $Triggers.PSObject.Properties.Name) {
        $trigger = $Triggers.$key
        $type = $trigger.type
        $kind = $key
        if ($trigger | Get-Member -MemberType Noteproperty -Name 'kind') {
            $kind = $($trigger.kind).ToUpper()
        }
        if ($trigger | Get-Member -MemberType Noteproperty -Name 'inputs') {

            if ($trigger.inputs | Get-Member Method) {
                $method = "$($trigger.inputs.method) "
            }

            if ($trigger | Select-Object -ExpandProperty inputs | Get-Member schema) {
                if ($trigger.inputs | Select-Object -ExpandProperty schema | Get-Member properties) {
                    $schema = $trigger.inputs.schema.properties | ConvertTo-Json -Compress
                }
            }
        }

        # Create PSCustomObject
        [PSCustomObject]@{
            Name   = "$kind $method$type"
            Type   = $type
            Kind   = $kind
            Method = $method
            Schema = $schema
        }
    }
}

function Compare-FileChecksumOfStrings {
    param (
        [string] $sourceString,
        [string] $TargetString

    )

     # Calculate hash of the Source file
    $stringAsStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($stringAsStream)
    $writer.write($sourceString)
    $writer.Flush()
    $stringAsStream.Position = 0
    $sourceHash = Get-FileHash -InputStream $stringAsStream | Select-Object Hash

    # Calculate hash of the new file
    $stringAsStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($stringAsStream)
    $writer.write($targetString)
    $writer.Flush()
    $stringAsStream.Position = 0
    $targetHash = Get-FileHash -InputStream $stringAsStream | Select-Object Hash

    Write-Verbose "Source Hash: $($sourceHash.hash)"
    Write-Verbose "New File Hash: $($targetHash.hash)"

    # If they the same, then return true
    [bool]($sourceHash.hash -eq $targetHash.hash)

}