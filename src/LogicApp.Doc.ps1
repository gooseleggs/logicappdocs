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
    
    Section 'Logic App Workflow Actions' {
        "This section shows an overview of Logic App Workflow actions and their dependencies."

        Section 'Actions' {            
            $($InputObject.actions) |                 
            Sort-Object -Property Order |  
            Select-Object -Property 'ActionName', 'Comment', 'Type', 'RunAfter', @{Name = 'Inputs'; Expression = { Format-MarkdownTableJson -Json $($_.Inputs | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Format-Json)} } |
            Table -Property 'ActionName', 'Comment', 'Type', 'RunAfter', 'Inputs'            
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
}