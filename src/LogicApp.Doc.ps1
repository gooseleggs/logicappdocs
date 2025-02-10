Document 'Azure-LogicApp-Documentation' {

    # Helper function
    Function Format-MarkdownTableJson {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $true)]
            $Json
        )

        ("<table><tr><td><pre>$Json</pre></td></tr></table>") -replace '\r\n', '<br>'
    }

    # Formats JSON in a nicer format than the built-in ConvertTo-Json does.
    function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json) {
        $indent = 0;
        ($json -Split '\n' |
        % {
            if ($_ -match '[\}\]]') {
                # This line contains  ] or }, decrement the indentation level
                if ($indent) {
                    $indent--
                }
            }
            $line = (' ' * $indent * 2) + $_.TrimStart().Replace(':  ', ': ')
            if ($_ -match '[\{\[]') {
                # This line contains [ or {, increment the indentation level
                $indent++
            }
            $line
        }) -Join "`n"
    }

    "# Azure Logic App Documentation - $($InputObject.LogicApp.name)"

    Section 'Introduction' {
        "This document describes the Azure Logic App Workflow **$($InputObject.LogicApp.name)** in the **$($InputObject.LogicApp.ResourceGroupName)** resource group in the **$($InputObject.LogicApp.SubscriptionName)** subscription."
        "This document is programmatically generated using a PowerShell script."
        
        "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

        "$($InputObject.Overview)"
    }

    Section 'Logic App Call-Out Diagram' -If {  $($InputObject.CalloutDiagram) -ne '' } {
        @"        
``````mermaid
$($InputObject.CalloutDiagram)
``````
"@         
    }

    Section 'Logic App Workflow Diagram' {
        @"        
``````mermaid
$($InputObject.diagram)
``````
"@       
    }
    
    Section 'Logic App Triggers' {
        "This section shows an overview of the Logic App Triggers"

        Section 'Triggers' {
            $($InputObject.triggers) |
            Select-Object -Property 'Name', 'Type', 'Kind', 'Method', @{Name = 'Schema'; Expression = { Format-MarkdownTableJson -Json $($_.Schema | ConvertFrom-Json | ConvertTo-Json -Depth 10)} } |
            Table -Property 'Name', 'Type', 'Kind', 'Method', 'Schema'
        }
    }

    if ($InputObject.Actions.Additional | select-Object { $_.type -eq 'SQL' } ) {
        Section 'SQL' {
            "This section details the connections to SQL."
            "If the *Connection Reference* is not detailed under the **Connections section** (may not be present) then the connection information can be found in Logic App."

            $($inputObject.Actions) |
            Where-object { $_.type -eq 'Sql' } |
            select-Object -Property @{Name='Action Name'; Expression = {$_.ActionName}},
                @{Name='Server'; Expression = { $_.additional.server }},
                @{Name='Database'; Expression = { $_.additional.database }},
                @{Name='Query Type'; Expression = { $_.additional.sqlType }},
                @{Name='Table/Procedure'; Expression = { $_.additional.procTable }},
                @{Name='Conn Ref'; Expression = { $_.additional.connRef }} |
            Table -Property 'Action Name', 'Conn Ref', 'Server', 'Database', 'Query Type', 'Table/Procedure'
        }
    }

    Section 'Logic App Workflow Actions' {
        "This section shows an overview of Logic App Workflow actions and their dependencies."

        Section 'Actions' {            
            $($InputObject.actions) |                 
            Sort-Object -Property Order |  
            Select-Object -Property 'ActionName', 'Comment', 'Type', 'RunAfter', @{Name = 'Inputs/Expressions'; Expression = { Format-MarkdownTableJson -Json $($_.Inputs | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Format-Json)} } |
            Table -Property 'ActionName', 'Comment', 'Type', 'RunAfter', 'Inputs/Expressions'            
        }
    }

    if ($InputObject.Connections) {
        Section 'Logic App Connections' {
            "This section shows an overview of Logic App Workflow connections."

            Section 'Connections' {
                $($InputObject.Connections) |
                Select-Object -Property 'ConnectionName', 'ConnectionId', @{Name = 'ConnectionProperties'; Expression = { Format-MarkdownTableJson -Json $($_.ConnectionProperties | ConvertTo-Json | Format-Json) } } |
                Table -Property 'ConnectionName', 'ConnectionId', 'ConnectionProperties'
            }
        }
    }

    # If we have any powershell file
    if (($InputObject.PowerShell).count) {
        Section 'PowerShell Scripts' {
            "This section details found Powershell Scripts."

            $($InputObject.PowerShell) | ForEach-Object {
                Section "$($_.Name)" {
                    '```powershell'
                   "$($_.Content)"
                   '```'
                }
            }
        }
    }
}