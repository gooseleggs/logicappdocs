# Azure Logic App Documentation - logic-jiraintegration-demo

## Introduction

This document describes the Azure Logic App Workflow **logic-jiraintegration-demo** in the **jiraintegration-demo-rg** resource group in the **Visual Studio Enterprise** subscription.

This document is programmatically generated using a PowerShell script.

Date: 2025-02-03 11:15:55

## Logic App Call-Out Diagram

```mermaid
mindmap
  root(logic-jiraintegration-demo)
    ApiConnection
      Create_a_new_issue__V2_
      Html_to_text_-_Summary_Communication
      Run_query_and_list_results
    Http
      https:#sol;#sol;contoso.atlassian.net_rest_api_3_issue_Compose_-_JIRA_Incident_Id_transitions ("https:#sol;#sol;contoso.atlassian.net/rest/api/3/issue/[Compose_-_JIRA_Incident_Id]/transitions")
      https:#sol;#sol;contoso.atlassian.net_rest_api_3_search ("https:#sol;#sol;contoso.atlassian.net/rest/api/3/search")

```

## Logic App Workflow Diagram

```mermaid
graph TB
    HTTP_Request["HTTP Request"]
    subgraph For_Each_-_SHA
    direction TB
        subgraph Condition_-_StatusIf [ ]
        direction TB
            Condition_-_Status{Condition_-_Status}
            subgraph Condition_-_Status-True [True&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;]
            direction TB
                Compose_-_Current_Item
                Compose_-_SHA_TimeGeneratedUTC
                Compose_-_Subscriptions_Array
                Create_a_new_issue__V2_
                Html_to_text_-_Summary_Communication
            end
            subgraph Condition_-_Status-False [False&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;]
            direction TB
                Compose_-_Resolved_-_Current_Item
                For_Each_-_JIRA_SHA_Incident
                HTTP_-_Get_all_Active_JIRA_SHA_Incidents
                Parse_JSON_-_HTTP_-_Get_all_Active_JIRA_SHA_Incidents
            end
        end
    end
    subgraph For_Each_-_JIRA_SHA_Incident
    direction TB
        Compose_-_Current_JIRA_SHA_Incident
        Compose_-_JIRA_Incident_Id
        Compose_-_TICKET_ID_Number
        subgraph ConditionIf [ ]
        direction TB
            Condition{Condition}
            subgraph Condition-True [True&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;]
            direction TB
                HTTP_-_Close_JIRA_SHA_Incident
            end
        end
    end
    Parse_JSON_-_Log_Analytics_Search_Query --> Condition_-_Status
    Compose_-_SHA_TimeGeneratedUTC --> Compose_-_Current_Item
    Condition_-_Status --> Compose_-_SHA_TimeGeneratedUTC
    Compose_-_Current_Item --> Compose_-_Subscriptions_Array
    Html_to_text_-_Summary_Communication --> Create_a_new_issue__V2_
    Compose_-_Subscriptions_Array --> Html_to_text_-_Summary_Communication
    Condition_-_Status --> Compose_-_Resolved_-_Current_Item
    Parse_JSON_-_HTTP_-_Get_all_Active_JIRA_SHA_Incidents --> Compose_-_Current_JIRA_SHA_Incident
    Compose_-_TICKET_ID_Number --> Compose_-_JIRA_Incident_Id
    Compose_-_Current_JIRA_SHA_Incident --> Compose_-_TICKET_ID_Number
    Compose_-_JIRA_Incident_Id --> Condition
    Condition --> HTTP_-_Close_JIRA_SHA_Incident
    Compose_-_Resolved_-_Current_Item --> HTTP_-_Get_all_Active_JIRA_SHA_Incidents
    HTTP_-_Get_all_Active_JIRA_SHA_Incidents --> Parse_JSON_-_HTTP_-_Get_all_Active_JIRA_SHA_Incidents
    Run_query_and_list_results --> Parse_JSON_-_Log_Analytics_Search_Query
    Parse_JSON --> Run_query_and_list_results
    HTTP_Request["HTTP Request"] --> Parse_JSON

```

## Logic App Triggers

This section shows an overview of the Logic App Triggers

### Triggers

| Name | Type | Kind | Method | Schema |
| ---- | ---- | ---- | ------ | ------ |
| HTTP Request | Request | HTTP |  | |

## Logic App Workflow Actions

This section shows an overview of Logic App Workflow actions and their dependencies.

### Actions

| ActionName | Comment | Type | RunAfter | Inputs/Expressions |
| ---------- | ------- | ---- | -------- | ------------------ |
| Condition |  | If | Compose_-_JIRA_Incident_Id | <table><tr><td><pre>{<br>  "and": [<br>    {<br>      "contains": [<br>      "@outputs(\u0027Compose_-_Current_JIRA_SHA_Incident\u0027)[\u0027fields\u0027][\u0027summary\u0027]",<br>      "@items(\u0027For Each - SHA\u0027)[\u0027TICKET_ID_Number\u0027]"<br>      ]<br>    }<br>  ]<br>}</pre></td></tr></table> |
| HTTP_-_Close_JIRA_SHA_Incident |  | Http | Condition | <table><tr><td><pre>{<br>  "body": {<br>    "transition": {<br>      "id": "111"<br>    },<br>    "update": {<br>      "comment": [<br>        {<br>          "add": {<br>            "body": {<br>              "content": [<br>                {<br>                  "content": [<br>                    {<br>                      "text": "Azure Service Health Alert Incident automatically resolved via Log Analytics Workflow",<br>                      "type": "text"<br>                    }<br>                  ],<br>                  "type": "paragraph"<br>                }<br>              ],<br>              "type": "doc",<br>              "version": 1<br>            }<br>          }<br>        }<br>      ]<br>    }<br>  },<br>  "headers": {<br>    "Authorization": "Basic ******"<br>  },<br>  "method": "POST",<br>"uri": "https://contoso.atlassian.net/rest/api/3/issue/@{outputs(\u0027Compose_-_JIRA_Incident_Id\u0027)}/transitions"<br>}</pre></td></tr></table> |
| Compose_-_JIRA_Incident_Id |  | Compose | Compose_-_TICKET_ID_Number | <table><tr><td><pre>"@items(\u0027For_Each_-_JIRA_SHA_Incident\u0027)[\u0027id\u0027]"</pre></td></tr></table> |
| Compose_-_TICKET_ID_Number |  | Compose | Compose_-_Current_JIRA_SHA_Incident | <table><tr><td><pre>"@items(\u0027For Each - SHA\u0027)?[\u0027TICKET_ID_Number\u0027]"</pre></td></tr></table> |
| HTTP_-_Get_all_Active_JIRA_SHA_Incidents |  | Http | Compose_-_Resolved_-_Current_Item | <table><tr><td><pre>{<br>  "headers": {<br>    "Authorization": "Basic ******"<br>  },<br>  "method": "GET",<br>"uri": "https://contoso.atlassian.net/rest/api/3/search?jql=Status!=Completed%20and%20cf[10041]~\"Azure\"\u0026fields=key,summary,status,resolution,customfield_10041,description"<br>}</pre></td></tr></table> |
| Parse_JSON |  | ParseJson |  | <table><tr><td><pre>{<br>  "content": "@triggerBody()",<br>  "schema": {<br>    "properties": {<br>      "data": {<br>        "properties": {<br>          "alertContext": {<br>            "properties": {<br>              "condition": {<br>                "properties": {<br>                  "allOf": {<br>                    "items": {<br>                    "properties": "@{dimensions=; failingPeriods=; linkToFilteredSearchResultsAPI=; linkToFilteredSearchResultsUI=; linkToSearchResultsAPI=; linkToSearchResultsUI=; metricMeasureColumn=; metricValue=; operator=; searchQuery=; targetResourceTypes=; threshold=; timeAggregation=}",<br>                      "required": "searchQuery metricMeasureColumn targetResourceTypes operator threshold timeAggregation dimensions metricValue failingPeriods linkToSearchResultsUI linkToFilteredSearchResultsUI linkToSearchResultsAPI linkToFilteredSearchResultsAPI",<br>                      "type": "object"<br>                    },<br>                    "type": "array"<br>                  },<br>                  "windowEndTime": {<br>                    "type": "string"<br>                  },<br>                  "windowSize": {<br>                    "type": "string"<br>                  },<br>                  "windowStartTime": {<br>                    "type": "string"<br>                  }<br>                },<br>                "type": "object"<br>              },<br>              "conditionType": {<br>                "type": "string"<br>              },<br>              "properties": {<br>                "properties": {<br>                                   },<br>                "type": "object"<br>              }<br>            },<br>            "type": "object"<br>          },<br>          "customProperties": {<br>                       },<br>          "essentials": {<br>            "properties": {<br>              "alertContextVersion": {<br>                "type": "string"<br>              },<br>              "alertId": {<br>                "type": "string"<br>              },<br>              "alertRule": {<br>                "type": "string"<br>              },<br>              "alertTargetIDs": {<br>                "items": {<br>                  "type": "string"<br>                },<br>                "type": "array"<br>              },<br>              "configurationItems": {<br>                "items": {<br>                  "type": "string"<br>                },<br>                "type": "array"<br>              },<br>              "description": {<br>                "type": "string"<br>              },<br>              "essentialsVersion": {<br>                "type": "string"<br>              },<br>              "firedDateTime": {<br>                "type": "string"<br>              },<br>              "monitorCondition": {<br>                "type": "string"<br>              },<br>              "monitoringService": {<br>                "type": "string"<br>              },<br>              "originAlertId": {<br>                "type": "string"<br>              },<br>              "severity": {<br>                "type": "string"<br>              },<br>              "signalType": {<br>                "type": "string"<br>              }<br>            },<br>            "type": "object"<br>          }<br>        },<br>        "type": "object"<br>      },<br>      "schemaId": {<br>        "type": "string"<br>      }<br>    },<br>    "type": "object"<br>  }<br>}</pre></td></tr></table> |
| Run_query_and_list_results |  | ApiConnection | Parse_JSON | <table><tr><td><pre>{<br>"body": "@{body(\u0027Parse_JSON\u0027)[\u0027data\u0027][\u0027alertContext\u0027][\u0027Condition\u0027][\u0027allOf\u0027][0][\u0027searchQuery\u0027]}",<br>  "host": {<br>    "connection": {<br>    "name": "@parameters(\u0027$connections\u0027)[\u0027azuremonitorlogs\u0027][\u0027connectionId\u0027]"<br>    }<br>  },<br>  "method": "post",<br>  "path": "/queryData",<br>  "queries": {<br>    "resourcegroups": "la-demo-rg",<br>    "resourcename": "la-demo-workspace",<br>    "resourcetype": "Log Analytics Workspace",<br>    "subscriptions": "fbca04ea-152b-415f-82a4-ae1ffc5f4267",<br>    "timerange": "Last hour"<br>  }<br>}</pre></td></tr></table> |
| Parse_JSON_-_HTTP_-_Get_all_Active_JIRA_SHA_Incidents |  | ParseJson | HTTP_-_Get_all_Active_JIRA_SHA_Incidents | <table><tr><td><pre>{<br>  "content": "@body(\u0027HTTP_-_Get_all_Active_JIRA_SHA_Incidents\u0027)",<br>  "schema": {<br>    "properties": {<br>      "expand": {<br>        "type": "string"<br>      },<br>      "issues": {<br>        "items": {<br>          "properties": {<br>            "expand": {<br>              "type": "string"<br>            },<br>            "fields": {<br>              "properties": {<br>                "customfield_10041": {<br>                  "type": "string"<br>                },<br>                "description": {<br>                  "properties": {<br>                    "content": {<br>                    "items": "@{properties=; required=System.Object[]; type=object}",<br>                      "type": "array"<br>                    },<br>                    "type": {<br>                      "type": "string"<br>                    },<br>                    "version": {<br>                      "type": "integer"<br>                    }<br>                  },<br>                  "type": "object"<br>                },<br>                "resolution": {<br>                                   },<br>                "status": {<br>                  "properties": {<br>                    "description": {<br>                      "type": "string"<br>                    },<br>                    "iconUrl": {<br>                      "type": "string"<br>                    },<br>                    "id": {<br>                      "type": "string"<br>                    },<br>                    "name": {<br>                      "type": "string"<br>                    },<br>                    "self": {<br>                      "type": "string"<br>                    },<br>                    "statusCategory": {<br>                    "properties": "@{colorName=; id=; key=; name=; self=}",<br>                      "type": "object"<br>                    }<br>                  },<br>                  "type": "object"<br>                },<br>                "summary": {<br>                  "type": "string"<br>                }<br>              },<br>              "type": "object"<br>            },<br>            "id": {<br>              "type": "string"<br>            },<br>            "key": {<br>              "type": "string"<br>            },<br>            "self": {<br>              "type": "string"<br>            }<br>          },<br>          "required": [<br>            "expand",<br>            "id",<br>            "self",<br>            "key",<br>            "fields"<br>          ],<br>          "type": "object"<br>        },<br>        "type": "array"<br>      },<br>      "maxResults": {<br>        "type": "integer"<br>      },<br>      "startAt": {<br>        "type": "integer"<br>      },<br>      "total": {<br>        "type": "integer"<br>      }<br>    },<br>    "type": "object"<br>  }<br>}</pre></td></tr></table> |
| Parse_JSON_-_Log_Analytics_Search_Query |  | ParseJson | Run_query_and_list_results | <table><tr><td><pre>{<br>  "content": "@body(\u0027Run_query_and_list_results\u0027)",<br>  "schema": {<br>    "properties": {<br>      "AZURE_SERVICE": {<br>        "type": "string"<br>      },<br>      "IMPACT": {<br>        "type": "string"<br>      },<br>      "JIRA_ASSIGNMENT_GROUP": {<br>        "type": "string"<br>      },<br>      "JIRA_COMPONENT_NAME": {<br>        "type": "string"<br>      },<br>      "SUMMARY_Communication": {<br>        "type": "string"<br>      },<br>      "SUMMARY_Title": {<br>        "type": "string"<br>      },<br>      "Status": {<br>        "type": "string"<br>      },<br>      "Subscriptions": {<br>        "type": "string"<br>      },<br>      "TICKET_ID_Number": {<br>        "type": "string"<br>      },<br>      "TimeGenerated": {<br>        "type": "string"<br>      }<br>    },<br>    "type": "object"<br>  }<br>}</pre></td></tr></table> |
| Compose_-_Current_JIRA_SHA_Incident |  | Compose | For_Each_-_JIRA_SHA_Incident | <table><tr><td><pre>"@items(\u0027For_Each_-_JIRA_SHA_Incident\u0027)"</pre></td></tr></table> |
| Compose_-_Current_Item |  | Compose | Compose_-_SHA_TimeGeneratedUTC | <table><tr><td><pre>"@items(\u0027For Each - SHA\u0027)"</pre></td></tr></table> |
| Compose_-_SHA_TimeGeneratedUTC |  | Compose | Condition_-_Status | <table><tr><td><pre>"@items(\u0027For Each - SHA\u0027)?[\u0027TimeGeneratedUTC\u0027]"</pre></td></tr></table> |
| For_Each_-_SHA |  | Foreach | Parse_JSON_-_Log_Analytics_Search_Query | <table><tr><td><pre>"@body(\u0027Parse JSON - Log Analytics Search Query\u0027)?[\u0027value\u0027]"</pre></td></tr></table> |
| Condition_-_Status |  | If | For_Each_-_SHA | <table><tr><td><pre>{<br>  "and": [<br>    {<br>      "equals": [<br>      "@items(\u0027For Each - SHA\u0027)?[\u0027Status\u0027]",<br>        "Active"<br>      ]<br>    }<br>  ]<br>}</pre></td></tr></table> |
| Compose_-_Subscriptions_Array |  | Compose | Compose_-_Current_Item | <table><tr><td><pre>"@array(items(\u0027For Each - SHA\u0027).Subscriptions)"</pre></td></tr></table> |
| Compose_-_Resolved_-_Current_Item |  | Compose | Condition_-_Status | <table><tr><td><pre>"@items(\u0027For Each - SHA\u0027)"</pre></td></tr></table> |
| For_Each_-_JIRA_SHA_Incident |  | Foreach | Parse_JSON_-_HTTP_-_Get_all_Active_JIRA_SHA_Incidents | <table><tr><td><pre>"@body(\u0027Parse_JSON_-_HTTP_-_Get_all_Active_JIRA_SHA_Incidents\u0027)?[\u0027issues\u0027]"</pre></td></tr></table> |
| Create_a_new_issue__V2_ |  | ApiConnection | Html_to_text_-_Summary_Communication | <table><tr><td><pre>{<br>  "body": {<br>    "fields": {<br>      "customfield_10041": "Azure",<br>    "customfield_10065": "@items(\u0027For Each - SHA\u0027)?[\u0027JIRA_ASSIGNMENT_GROUP\u0027]",<br>    "description": "Azure Service Health Issue\n\nStatus: @{items(\u0027For Each - SHA\u0027)?[\u0027Status\u0027]} \nStart Time: @{items(\u0027For Each - SHA\u0027)?[\u0027TimeGeneratedUTC\u0027]}\nSummary of Impact: @{body(\u0027Html to text - Summary Communication\u0027)}\nTracking ID: @{items(\u0027For Each - SHA\u0027)?[\u0027TICKET_ID_Number\u0027]}\nImpacted Services: @{items(\u0027For Each - SHA\u0027)?[\u0027AZURE_SERVICE\u0027]}\nImpacted Subscriptions: @{items(\u0027For Each - SHA\u0027)?[\u0027Subscriptions\u0027]}",<br>    "summary": "@{items(\u0027For Each - SHA\u0027)?[\u0027SUMMARY_Title\u0027]} - @{items(\u0027For Each - SHA\u0027)?[\u0027TICKET_ID_Number\u0027]}"<br>    }<br>  },<br>  "host": {<br>    "connection": {<br>    "name": "@parameters(\u0027$connections\u0027)[\u0027jira\u0027][\u0027connectionId\u0027]"<br>    }<br>  },<br>  "method": "post",<br>  "path": "/v2/issue",<br>  "queries": {<br>    "issueTypeIds": "10005",<br>    "projectKey": "IP"<br>  }<br>}</pre></td></tr></table> |
| Html_to_text_-_Summary_Communication |  | ApiConnection | Compose_-_Subscriptions_Array | <table><tr><td><pre>{<br>"body": "\u003cp\u003e@{items(\u0027For Each - SHA\u0027)?[\u0027SUMMARY_Communication\u0027]}\u003c/p\u003e",<br>  "host": {<br>    "connection": {<br>    "name": "@parameters(\u0027$connections\u0027)[\u0027conversionservice\u0027][\u0027connectionId\u0027]"<br>    }<br>  },<br>  "method": "post",<br>  "path": "/html2text"<br>}</pre></td></tr></table> |

## Logic App Connections

This section shows an overview of Logic App Workflow connections.

### Connections

| ConnectionName | ConnectionId | ConnectionProperties |
| -------------- | ------------ | -------------------- |
| azuremonitorlogs | /subscriptions/fbca04ea-152b-415f-82a4-ae1ffc5f4267/resourceGroups/jiraintegration-demo-rg/providers/Microsoft.Web/connections/azuremonitorlogs | <table><tr><td><pre></pre></td></tr></table> |
| conversionservice | /subscriptions/fbca04ea-152b-415f-82a4-ae1ffc5f4267/resourceGroups/jiraintegration-demo-rg/providers/Microsoft.Web/connections/conversionservice | <table><tr><td><pre></pre></td></tr></table> |
| jira-3 | /subscriptions/fbca04ea-152b-415f-82a4-ae1ffc5f4267/resourceGroups/jiraintegration-demo-rg/providers/Microsoft.Web/connections/jira-3 | <table><tr><td><pre></pre></td></tr></table> |
