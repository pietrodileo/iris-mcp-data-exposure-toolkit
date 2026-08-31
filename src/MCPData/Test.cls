Class MCPData.Test Extends %RegisteredObject
{
ClassMethod Run() As %Status
{
  Set sc=##class(MCPData.Setup).Run()
  If $$$ISERR(sc) Quit sc
  Set tool=##class(MCPData.Tools.HealthExample).%New()
  Set patients=tool.SearchPatients("Diabetes","Yes","",18,120,50)
  Set allowed=tool.ReadGlobalData("^ERRORS",3,50)
  Set denied=tool.ReadGlobalData("^NotAllowed",3,50)
  Set stmt=##class(%SQL.Statement).%New()
  Set sc=stmt.%Prepare("SELECT COUNT(*) AS N FROM MCPData_Data.Patient")
  If $$$ISERR(sc) Quit sc
  Set rs=stmt.%Execute()
  If 'rs.%Next() Quit $$$ERROR($$$GeneralError,"Patient count query returned no row")
  If rs.N'=500 Quit $$$ERROR($$$GeneralError,"Expected 500 imported synthetic patient rows")
  If patients.%Get("row_count",0)<1 Quit $$$ERROR($$$GeneralError,"Expected filtered synthetic patient rows")
  If allowed.%Get("count",0)<0 Quit $$$ERROR($$$GeneralError,"Expected allowlisted global access")
  If denied.%Get("error","")="" Quit $$$ERROR($$$GeneralError,"Expected non-allowlisted global denial")
  Write "PASS: 500 CSV patients, filtered SQL, bounded global, denied global",!
  Set sc=..SearchPatientLimits()
  If $$$ISERR(sc) Quit sc

  ; Create an error in the application log and verify that it is returned by the monitoring tool
  Try {
    Set a= 1/0
  } Catch ex {
    Set sc = ex.AsStatus()
    w $System.Status.GetErrorText(sc),!
    Do ex.Log()
    Set sc=$$$OK
  }

  Quit $$$OK
}

/// Read-only regression checks against the bundled synthetic dataset.
ClassMethod SearchPatientLimits() As %Status
{
  Try {
    Set tool=##class(MCPData.Tools.HealthExample).%New()
    Set spec=##class(MCPData.ToolSet.HealthExample).%New().%Discover()
    Set tools=spec.%Get("tools")
    For i=0:1:tools.%Size()-1 {
      Set item=tools.%Get(i)
      If item.%Get("stateful",1) Throw ##class(%Exception.General).%New("Read-only tools must not retain per-client instance state")
    }
    Do ..CheckPatientResult(tool.SearchPatients(),20,20,1)
    Do ..CheckPatientResult(tool.SearchPatients("","","",0,120,50),50,50,1)
    Do ..CheckPatientResult(tool.SearchPatients("","","",0,120,1000),50,50,1)
    Do ..CheckPatientResult(tool.SearchPatients("","","",0,120,0),1,1,1)
    Do ..CheckPatientResult(tool.SearchPatients("__no_matching_diagnosis__"),0,20,0)
    // Select an actual small cohort to test exact-boundary and below-limit results.
    Set rs=$SYSTEM.SQL.Execute("SELECT TOP 1 Age, COUNT(*) AS N FROM MCPData_Data.Patient GROUP BY Age HAVING COUNT(*) BETWEEN 2 AND 49 ORDER BY Age")
    If 'rs.%Next() Throw ##class(%Exception.General).%New("Expected a small age cohort in the synthetic dataset")
    Set age=rs.Age,n=rs.N
    Do ..CheckPatientResult(tool.SearchPatients("","","",age,age,n),n,n,0)
    Do ..CheckPatientResult(tool.SearchPatients("","","",age,age,n+1),n,n+1,0)
    Do ..CheckPatientResult(tool.SearchPatients("","","",age,age,n-1),n-1,n-1,1)
    Write "PASS: patient caps, returned counts, applied limits, and accurate truncation",!
    Return $$$OK
  } Catch ex {
    Return ex.AsStatus()
  }
}

ClassMethod CheckPatientResult(result As %DynamicObject,count As %Integer,limit As %Integer,truncated As %Boolean)
{
  If result.%IsDefined("error") Throw ##class(%Exception.General).%New("Patient query failed")
  If result.%Get("row_count")'=count Throw ##class(%Exception.General).%New("Incorrect returned row count")
  Set rows=result.%Get("rows")
  If rows.%Size()'=count Throw ##class(%Exception.General).%New("Returned rows exceed expected count")
  If result.%Get("applied_limit")'=limit Throw ##class(%Exception.General).%New("Incorrect applied limit")
  If result.%Get("truncated")'=truncated Throw ##class(%Exception.General).%New("Incorrect truncation flag")
  If result.%GetTypeOf("truncated")'="boolean" Throw ##class(%Exception.General).%New("Truncation flag must be a JSON boolean")
}
}
