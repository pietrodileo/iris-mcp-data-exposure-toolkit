Class MCPData.Policy.Audit Extends (%AI.Policy.Audit, %XML.Adaptor)
{
Parameter XMLNAME="Audit";
Method %LogExecution(call As %DynamicObject,metadata As %DynamicObject,result As %DynamicObject,duration As %Integer,status As %Status) As %Status
{
  Set row=##class(MCPData.Data.Audit).%New()
  Set toolName=call.%Get("name","unknown")
  Set args=call.%Get("arguments",{})
  
  Set row.ToolName=toolName
  Set row.DurationMs=duration
  Set row.StatusText=$SYSTEM.Status.GetErrorText(status)
  Set row.ResultCount=0
  If $ISOBJECT(result) {
    Set row.ResultCount=+result.%Get("row_count",result.%Get("count",0))
  }
  
  // Tool-specific audit fields
  If toolName="SearchPatients" {
    Set row.AuditType="SQL"
    Set row.FilterDiagnosis=args.%Get("diagnosis")
    Set row.FilterDiabetic=args.%Get("diabetic")
    Set row.FilterSmoker=args.%Get("smoker")
    Set row.FilterMinAge=args.%Get("minimumAge")
    Set row.FilterMaxAge=args.%Get("maximumAge")
  } ElseIf toolName ["Global" {
    Set row.AuditType="Global"
    Set row.GlobalPath=args.%Get("path")
    Set row.TraversalDepth=args.%Get("depth")
    Set row.ResultLimit=args.%Get("limit")
    Set row.TargetNamespace=args.%Get("namespace")
  }
  
  Quit row.%Save()
}

}
