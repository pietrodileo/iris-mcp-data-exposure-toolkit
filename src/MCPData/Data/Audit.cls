Class MCPData.Data.Audit Extends %Persistent
{
    
Property CreatedAt As %TimeStamp [ InitialExpression={$ZDATETIME($HOROLOG,3)} ];
    
Property ToolName As %String(MAXLEN=120);
    
Property DurationMs As %Integer;
    
Property StatusText As %String(MAXLEN=500);
    
Property ResultCount As %Integer;

// Audit type: SQL, Global, or empty for default
Property AuditType As %String(MAXLEN=50);

// SQL-specific filters
Property FilterDiagnosis As %String(MAXLEN=100);
Property FilterDiabetic As %String(MAXLEN=20);
Property FilterSmoker As %String(MAXLEN=20);
Property FilterMinAge As %Integer;
Property FilterMaxAge As %Integer;

// Global-specific parameters
Property GlobalPath As %String(MAXLEN=200);
Property TraversalDepth As %Integer;
Property ResultLimit As %Integer;
Property TargetNamespace As %String(MAXLEN=100);

Storage Default
{
<Data name="AuditDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>CreatedAt</Value>
</Value>
<Value name="3">
<Value>ToolName</Value>
</Value>
<Value name="4">
<Value>DurationMs</Value>
</Value>
<Value name="5">
<Value>StatusText</Value>
</Value>
<Value name="6">
<Value>ResultCount</Value>
</Value>
<Value name="7">
<Value>AuditType</Value>
</Value>
<Value name="8">
<Value>FilterDiagnosis</Value>
</Value>
<Value name="9">
<Value>FilterDiabetic</Value>
</Value>
<Value name="10">
<Value>FilterSmoker</Value>
</Value>
<Value name="11">
<Value>FilterMinAge</Value>
</Value>
<Value name="12">
<Value>FilterMaxAge</Value>
</Value>
<Value name="13">
<Value>GlobalPath</Value>
</Value>
<Value name="14">
<Value>TraversalDepth</Value>
</Value>
<Value name="15">
<Value>ResultLimit</Value>
</Value>
<Value name="16">
<Value>TargetNamespace</Value>
</Value>
</Data>
<DataLocation>^MCPData.Data.AuditD</DataLocation>
<DefaultData>AuditDefaultData</DefaultData>
<IdLocation>^MCPData.Data.AuditD</IdLocation>
<IndexLocation>^MCPData.Data.AuditI</IndexLocation>
<StreamLocation>^MCPData.Data.AuditS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}

