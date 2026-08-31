Class MCPData.Policy.Authorization Extends (%AI.Policy.Authorization, %XML.Adaptor)
{
Parameter XMLNAME="Authorization";

/// This method is called to determine if a tool can be executed. It should return $$$OK if the tool can be executed, or an error status if it cannot.
/// It can define allowlists or other logic to determine if the tool is allowed to be executed. It can also modify the call arguments if needed.
Method %CanExecute(tool As %String,call As %DynamicObject,metadata As %DynamicObject) As %Status
{
  Set name=tool
  If $ISOBJECT(call) Set name=call.%Get("name",name)
  Set allowlist=$LISTBUILD("ListResources","SearchPatients","ReadGlobalData","LargestGlobals","RecentApplicationErrors") 
  If $LISTFIND(allowlist,name)=0 { 
    Quit ..Deny(name,call,"Tool is not allowlisted: "_name)
  }
  If '$ISOBJECT(call) Quit ..Deny(name,call,"Invalid call")
  Set args=call.%Get("arguments",{})
  Set encoded='$ISOBJECT(args)
  If encoded {
    Try {
      Set args=##class(%DynamicObject).%FromJSON(args)
    } Catch ex {
      Return ..Deny(name,call,"Arguments must be a JSON object")
    }
  }
  If '$ISOBJECT(args) Quit ..Deny(name,call,"Arguments must be a JSON object")
  If 'args.%IsA("%Library.DynamicObject") Quit ..Deny(name,call,"Arguments must be a JSON object")
  // Reject nested values before scalar validation or audit-field extraction.
  Set fields=$LISTBUILD("path","limit","depth","diagnosis","diabetic","smoker","minimumAge","maximumAge")
  For i=1:1:$LISTLENGTH(fields) {
    Set field=$LISTGET(fields,i)
    Set kind=args.%GetTypeOf(field)
    If kind="object"!(kind="array") Return ..Deny(name,call,"Tool arguments must be scalar values")
  }
  If name="ReadGlobalData",args.%Get("path","^ERRORS")'="^ERRORS" Quit ..Deny(name,call,"Only ^ERRORS global is allowed")
  If args.%IsDefined("limit") {
    Set limit=+args.%Get("limit")
    If limit<1 Set limit=1
    If limit>50 Set limit=50
    Do args.%Set("limit",limit)
  }
  If args.%IsDefined("depth") {
    Set depth=+args.%Get("depth")
    If depth<1 Set depth=1
    If depth>3 Set depth=3
    Do args.%Set("depth",depth)
  }
  // Preserve the representation expected by the caller when forwarding changes.
  If encoded Do call.%Set("arguments",args.%ToJSON())
  Else  Do call.%Set("arguments",args)
  Quit $$$OK
}

/// This EAP does not invoke the execution audit callback for authorization denials.
/// Record the rejected attempt here; no tool ran, so duration and result count are zero.
Method Deny(name As %String,call As %Any,message As %String) As %Status [ Private ]
{
  Set status=$$$ERROR($$$AICoreToolAccessDenied,message)
  If '$ISOBJECT(call) Set call={"name":(name),"arguments":{}}
  Set audit=##class(MCPData.Policy.Audit).%New()
  Set sc=audit.%LogExecution(call,{},"",0,status)
  If $$$ISERR(sc) Quit $$$ADDSC(status,sc)
  Quit status
}
}
