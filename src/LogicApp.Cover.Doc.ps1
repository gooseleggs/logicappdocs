Document 'Azure-Standard-LogicApp-Documentation' {

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
        "This document describes the Standard Azure Logic App **$($InputObject.LogicApp.name)** in the **$($InputObject.LogicApp.ResourceGroupName)** resource group in the **$($InputObject.LogicApp.SubscriptionName)** subscription."
        "This document is programmatically generated using a PowerShell script."
        
        "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    }
   
    Section 'Workflows' {
        "This section details the workflows defined within the logic App."

        "**NOTE** The LastWriteTime is when the file was last updated from the Logic App AND NOT when the logic app was updated."

        Section 'Workflows' {
            $($InputObject.LogicApp.Workflows) |
            Select-Object -Property @{Name = 'Workflow'; Expression = { "[$($_.Name)]($($InputObject.LogicApp.OutputPath)$($_.Name).md)"  }}, LastWriteTime |
            Table -Property 'Workflow', 'LastWriteTime'

        }

    }

    Section 'Parameters' {
        "This section shows the parameters defined within the logic App"

        Section 'Parameters' {
            $($InputObject.LogicApp.Parameters) |
            Select-Object -Property 'Name', 'Type', 'Value' |
            Table -Property 'Name', 'Type', 'Value'
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