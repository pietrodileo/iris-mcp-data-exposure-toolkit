Class MCPData.Policy.Audit Extends (%AI.Policy.Audit, %XML.Adaptor)
{
Parameter XMLNAME="Audit";
Method %LogExecution(call As %DynamicObject,metadata As %DynamicObject,result As %DynamicObject,duration As %Integer,status As %Status) As %Status
{
  Set row=##class(MCPData.Data.Audit).%New()
  Set toolName=call.%Get("name","unknown")
  // The MCP bridge supplies arguments as JSON text; direct callers may use an object.
  Set args=..AsObject(call.%Get("arguments",{}))
  Set payload=..AsObject(result)
  If payload.%IsDefined("result_json") Set payload=..AsObject(payload.%Get("result_json"))
  
  Set row.ToolName=$EXTRACT(toolName,1,120)
  Set row.DurationMs=duration
  Set row.StatusText=$EXTRACT($SYSTEM.Status.GetErrorText(status),1,500)
  If $$$ISOK(status),payload.%IsDefined("error") Set row.StatusText=$EXTRACT("Application error: "_payload.%Get("error"),1,500)
  Set row.ResultCount=0
  If payload.%IsDefined("row_count") {
    Set row.ResultCount=+payload.%Get("row_count")
  } ElseIf payload.%IsDefined("count") {
    Set row.ResultCount=+payload.%Get("count")
  } Else {
    Set rows=payload.%Get("rows")
    If $ISOBJECT(rows),rows.%IsA("%Library.DynamicArray") Set row.ResultCount=rows.%Size()
  }
  
  // Tool-specific audit fields
  If toolName="SearchPatients" {
    Set row.AuditType="SQL"
    Set row.FilterDiagnosis=$EXTRACT(args.%Get("diagnosis"),1,100)
    Set row.FilterDiabetic=$EXTRACT(args.%Get("diabetic"),1,20)
    Set row.FilterSmoker=$EXTRACT(args.%Get("smoker"),1,20)
    If args.%IsDefined("minimumAge") Set row.FilterMinAge=+args.%Get("minimumAge")
    If args.%IsDefined("maximumAge") Set row.FilterMaxAge=+args.%Get("maximumAge")
  } ElseIf toolName ["Global" {
    Set row.AuditType="Global"
    Set row.GlobalPath=$EXTRACT(args.%Get("path"),1,200)
    If args.%IsDefined("depth") Set row.TraversalDepth=+args.%Get("depth")
    If args.%IsDefined("limit") Set row.ResultLimit=+args.%Get("limit")
    Set row.TargetNamespace="MCP_EXAMPLE"
  } ElseIf toolName="RecentApplicationErrors" {
    Set row.AuditType="Global"
    Set row.GlobalPath="^ERRORS"
    If args.%IsDefined("limit") Set row.ResultLimit=+args.%Get("limit")
    Set row.TargetNamespace="MCP_EXAMPLE"
  }
  
  Quit row.%Save()
}

/// Normalize AI Hub JSON envelopes without letting absent/error payloads prevent auditing.
ClassMethod AsObject(value As %Any) As %DynamicObject [ Private ]
{
  If $ISOBJECT(value) {
    If value.%IsA("%Library.DynamicObject") Quit value
    Quit {}
  }
  Try {
    Set parsed=##class(%DynamicObject).%FromJSON(value)
    If $ISOBJECT(parsed),parsed.%IsA("%Library.DynamicObject") Return parsed
  } Catch ex {
    // Failed calls may have no JSON result. Still persist their execution status.
  }
  Quit {}
}

}
