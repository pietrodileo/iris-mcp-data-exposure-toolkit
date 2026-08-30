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
    Quit $$$ERROR($$$AICoreToolAccessDenied,"Tool is not allowlisted: "_name) 
  }
  If '$ISOBJECT(call) Quit $$$ERROR($$$AICoreToolAccessDenied,"Invalid call")
  Set args=call.%Get("arguments",{})
  If name="ReadGlobalData",args.%Get("path","^ERRORS")'="^ERRORS" Quit $$$ERROR($$$AICoreToolAccessDenied,"Only ^ERRORS global is allowed")
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
  Quit $$$OK
}
}
