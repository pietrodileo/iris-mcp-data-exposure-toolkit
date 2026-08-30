Class MCPData.Setup Extends %RegisteredObject
{

ClassMethod Run() As %Status
{
  Set sc=##class(MCPData.Data.Patient).ImportCSV()
  If $$$ISERR(sc) Quit sc
  Quit $$$OK
}

/// Method to configure the users for the demo. It will create a user with the APP_USER and APP_PASS environment variables, and grant it access to the Patient table.
ClassMethod ConfigureUsers() As %Status
{
  Set sc = $$$OK
  Try {
    New $Namespace
    Set bridge=$SYSTEM.Util.GetEnviron("WG_USER")
    Set bridgePass=$SYSTEM.Util.GetEnviron("WG_PASS")
    Set app=$SYSTEM.Util.GetEnviron("APP_USER")
    Set appPass=$SYSTEM.Util.GetEnviron("APP_PASS")
    If bridge=""!(bridgePass="")!(app="")!(appPass="") {
      Set sc = $$$ERROR($$$GeneralError,"WG_USER, WG_PASS, APP_USER and APP_PASS are required")
      $$$ThrowOnError(sc)
    }
    If app=bridge {
      Set sc = $$$ERROR($$$GeneralError,"APP_USER must be different from WG_USER")
      $$$ThrowOnError(sc)
    }
    Set sc=..GrantPatientSQLAccess()
    $$$ThrowOnError(sc)
    Set $Namespace="%SYS"
    If bridge'="CSPSystem" { 
      Set sc = $$$ERROR($$$GeneralError,"WG_USER must be built-in CSPSystem gateway identity for this demo")
      $$$ThrowOnError(sc)
    }
    If '##class(Security.Users).Exists(bridge) { 
      Set sc = $$$ERROR($$$GeneralError,"Built-in CSPSystem gateway identity is unavailable")
      $$$ThrowOnError(sc)
    }
    Kill props Set props("Password")=appPass,props("Roles")="MCPDataReader"
    If ##class(Security.Users).Exists(app) {
      Set sc=##class(Security.Users).Delete(app)
      $$$ThrowOnError(sc)
    }
    Set sc = ##class(Security.Users).Create(app,.props)
    $$$ThrowOnError(sc)
    w "Created user: "_app,!
  } Catch ex {
    Set sc = ex.AsStatus()
    w $System.Status.GetErrorText(sc),!
  }
  Return sc
}

ClassMethod GrantPatientSQLAccess() As %Status
{
  Set statement=##class(%SQL.Statement).%New()
  Set sc=statement.%Prepare("GRANT SELECT ON MCPData_Data.Patient TO MCPDataReader")
  If $$$ISERR(sc) Quit sc
  Set result=statement.%Execute()
  If result.%SQLCODE<0 Quit $$$ERROR($$$GeneralError,"SQLCODE "_result.%SQLCODE_": "_result.%Message)
  Quit $$$OK
}

}
