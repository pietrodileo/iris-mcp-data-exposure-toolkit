/// Regression tests for the AI Hub audit callback. Test records are rolled back.
Class MCPData.AuditTest Extends %RegisteredObject
{
ClassMethod Run() As %Status
{
  Set level=$TLEVEL
  TSTART
  Try {
    Set policy=##class(MCPData.Policy.Audit).%New()
    Set args={"diagnosis":"Diabetes","diabetic":"Yes","minimumAge":60,"limit":3}
    Set payload={"row_count":3,"rows":[]}
    Set call={"name":"SearchPatients","arguments":(args.%ToJSON())}
    Set result={"result_json":(payload.%ToJSON())}
    Do ..Check(policy,call,result,1,3,"SQL","Diabetes")
    // Direct ObjectScript callers still supply objects, not JSON strings.
    Do call.%Set("arguments",args)
    Do ..Check(policy,call,payload,1,3,"SQL","Diabetes")
    Do ..Check(policy,{"name":"ReadGlobalData","arguments":"{}"},{"result_json":"{\"count\":2}"},1,2,"Global")
    Do ..Check(policy,{"name":"LargestGlobals","arguments":"{\"limit\":5}"},{"result_json":"{\"rows\":[{},{}]}"},1,2,"Global")
    Do ..Check(policy,{"name":"RecentApplicationErrors","arguments":"{}"},{"result_json":"{\"rows\":[{}]}"},1,1,"Global")
    Do ..Check(policy,{"name":"ListResources","arguments":"{}"},{"result_json":"{}"},1,0,"")
    Set denied=$SYSTEM.Status.Error(5001,"Denied test call")
    Do ..Check(policy,{"name":"ReadGlobalData","arguments":"{\"path\":\"^NotAllowed\"}"},"",denied,0,"Global",,"Denied test call")
    Do ..Check(policy,call,{"result_json":"{\"error\":\"Invalid filter\"}"},1,0,"SQL","Diabetes","Application error: Invalid filter")
    // Long user-controlled strings used to exceed persistent property MAXLEN.
    Set long=$TRANSLATE($JUSTIFY("",600)," ","x")
    Do args.%Set("diagnosis",long)
    Do call.%Set("arguments",args.%ToJSON())
    Do ..Check(policy,call,{},$SYSTEM.Status.Error(5001,long),0,"SQL",$EXTRACT(long,1,100))
    Do ..Check(policy,{"name":"SearchPatients","arguments":"not-json"},{"result_json":"not-json"},denied,0,"SQL",,"Denied test call")
    Set auth=##class(MCPData.Policy.Authorization).%New()
    Set before=..LastId()
    Set sc=auth.%CanExecute("ReadGlobalData",{"name":"ReadGlobalData","arguments":{"path":"^NotAllowed"}}, {})
    If $$$ISOK(sc) Throw ##class(%Exception.General).%New("Expected authorization denial")
    Set after=..LastId()
    If after<=before Throw ##class(%Exception.General).%New("Authorization denial was not audited")
    Set row=##class(MCPData.Data.Audit).%OpenId(after)
    If row.GlobalPath'="^NotAllowed" Throw ##class(%Exception.General).%New("Missing denied path")
    If row.StatusText'["Only ^ERRORS" Throw ##class(%Exception.General).%New("Missing denial status")
    Do ..AuthorizationCases()
    TROLLBACK 1
    Write "PASS: audit JSON/object arguments, all tools, counts, failures, and field bounds",!
    Return $$$OK
  } Catch ex {
    If $TLEVEL>level TROLLBACK 1
    Return ex.AsStatus()
  }
}

ClassMethod Check(policy As MCPData.Policy.Audit,call As %DynamicObject,result As %Any,status As %Status,count As %Integer,category As %String,diagnosis As %String="",errorText As %String="")
{
  Set before=..LastId()
  Set sc=policy.%LogExecution(call,{},result,7,status)
  $$$ThrowOnError(sc)
  Set after=..LastId()
  If after<=before Throw ##class(%Exception.General).%New("Audit row was not saved")
  Set row=##class(MCPData.Data.Audit).%OpenId(after)
  If row.ToolName'=call.%Get("name") Throw ##class(%Exception.General).%New("Incorrect tool name")
  If row.ResultCount'=count Throw ##class(%Exception.General).%New("Incorrect result count")
  If row.AuditType'=category Throw ##class(%Exception.General).%New("Incorrect audit category")
  If row.FilterDiagnosis'=diagnosis Throw ##class(%Exception.General).%New("Incorrect diagnosis filter")
  If errorText'="",row.StatusText'[errorText Throw ##class(%Exception.General).%New("Missing failure status")
}

ClassMethod LastId() As %Integer
{
  Set rs=$SYSTEM.SQL.Execute("SELECT MAX(ID) AS LastId FROM MCPData_Data.Audit")
  If 'rs.%Next() Quit 0
  Quit +rs.LastId
}

ClassMethod AuthorizationCases()
{
  Set auth=##class(MCPData.Policy.Authorization).%New()
  For encoded=0:1:1 {
    Set args={"limit":1000,"depth":99}
    Set call={"name":"ReadGlobalData","arguments":(args)}
    If encoded Do call.%Set("arguments",args.%ToJSON())
    Set before=..LastId()
    Set sc=auth.%CanExecute("ReadGlobalData",call,{})
    $$$ThrowOnError(sc)
    Set actual=call.%Get("arguments")
    If encoded Set actual=##class(%DynamicObject).%FromJSON(actual)
    If actual.%Get("limit")'=50 Throw ##class(%Exception.General).%New("Authorization did not clamp limit")
    If actual.%Get("depth")'=3 Throw ##class(%Exception.General).%New("Authorization did not clamp depth")
    If ..LastId()'=before Throw ##class(%Exception.General).%New("Authorization audited a successful call twice")
  }
  Set invalid=["not-json","null","[]","123",{"path":{}},[1,2]]
  For i=0:1:invalid.%Size()-1 {
    Set call={"name":"ReadGlobalData","arguments":(invalid.%Get(i))}
    Set before=..LastId()
    Set sc=auth.%CanExecute("ReadGlobalData",call,{})
    If $$$ISOK(sc) Throw ##class(%Exception.General).%New("Malformed arguments were accepted")
    If ..LastId()<=before Throw ##class(%Exception.General).%New("Malformed arguments were not audited")
  }
}
}
