Class MCPData.ToolSet.HealthExample Extends %AI.ToolSet [ DependsOn=(MCPData.Tools.HealthExample,MCPData.Policy.Authorization,MCPData.Policy.Audit) ]
{

XData Definition [ MimeType=application/xml ]
{
<ToolSet Name="CareOutreachData">
  <Description>Read-only namespace monitoring and error inspection.</Description>
  <Policies><Authorization Class="MCPData.Policy.Authorization"/><Audit Class="MCPData.Policy.Audit"/></Policies>
  <Include Class="MCPData.Tools.HealthExample"/>
</ToolSet>

}

}

