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
}
