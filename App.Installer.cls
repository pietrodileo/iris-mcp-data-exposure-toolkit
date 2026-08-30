Class App.Installer
{
XData setup
{
<Manifest>
  <Default Name="NAMESPACE" Value="MCP_EXAMPLE"/>
  <Namespace Name="${NAMESPACE}"><Import File="/home/irisowner/dev/src" Recurse="1"/></Namespace>
  <Invoke Class="App.Installer" Method="RegisterMCP" CheckStatus="1"><Arg Value="${NAMESPACE}"/><Arg Value="/mcp/health-example"/><Arg Value="MCPData.Service.HealthExample"/></Invoke>
  <Namespace Name="${NAMESPACE}"><Invoke Class="MCPData.Setup" Method="Run" CheckStatus="1"/></Namespace>
</Manifest>
}
ClassMethod RegisterMCP(ns As %String,path As %String,dispatch As %String) As %Status
{
  New $Namespace
  Set $Namespace="%SYS"
  If '##class(Security.Roles).Exists("MCPDataReader") {
    Set sc=##class(Security.Roles).Create("MCPDataReader","Read-only care outreach MCP role","%DB_"_ns_"_CODE:R,%DB_"_ns_"_DATA:RW","")
    If $$$ISERR(sc) Quit sc
  }
  Set spec("AutheEnabled")=$$$AuthePassword
  Set spec("NameSpace")=ns
  Set spec("DispatchClass")=dispatch
  Set spec("Description")="Audited synthetic care outreach data"
  Set spec("IsNameSpaceDefault")=$$$NO
  Set spec("MatchRoles")=":MCPDataReader"
  Set spec("Enabled")=1
  Set spec("Type")=18
  If ##class(Security.Applications).Exists(path) Quit ##class(Security.Applications).Modify(path,.spec)
  Quit ##class(Security.Applications).Create(path,.spec)
}
ClassMethod setup(ByRef pVars,pLogLevel As %Integer=3,pInstaller As %Installer.Installer,pLogger As %Installer.AbstractLogger) As %Status [ CodeMode=objectgenerator, Internal ]
{
  Quit ##class(%Installer.Manifest).%Generate(%compiledclass,%code,"setup")
}
}
