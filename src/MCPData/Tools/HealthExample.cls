Class MCPData.Tools.HealthExample Extends %AI.Tool
{

/// List the available resources for this toolset. This method is called by the MCP framework to provide a list of available resources to the client.
Method ListResources() As %DynamicObject [ WebMethod ]
{
  Quit {
    "sql":["MCPData_Data.Patient"],
    "globals":["^ERRORS"],
    "operations":["LargestGlobals","RecentApplicationErrors","ReadGlobalData"],
    "synthetic":true,
    "readOnly":true,
    "maxResults":50,
    "maxDepth":3,
    "monitoringScope":"MCP_EXAMPLE namespace"
  }
}

/// Method to search for patients in the Patient table based on the provided filters. It returns a list of patients matching the criteria, limited by the specified limit.
Method SearchPatients(diagnosis As %String="",diabetic As %String="",smoker As %String="",minimumAge As %Integer=0,maximumAge As %Integer=120,limit As %Integer=20) As %DynamicObject [ WebMethod ]
{
  If limit<1 Set limit=1
  If limit>50 Set limit=50
  If minimumAge<0 Set minimumAge=0
  If maximumAge>120 Set maximumAge=120
  If maximumAge<minimumAge Set maximumAge=minimumAge
  Set diagnosisPattern=$SELECT(diagnosis="":"%",1:diagnosis_"%")
  Set diabeticFilter=$SELECT(diabetic="":"%",diabetic="Yes":1,diabetic="No":0,1:"invalid")
  Set smokerFilter=$SELECT(smoker="":"%",smoker="Yes":1,smoker="No":0,1:"invalid")
  If diabeticFilter="invalid"!(smokerFilter="invalid") Quit {"error":"diabetic and smoker must be Yes, No, or empty"}
  Set rows=[]
  Set out={"source":"iris","imported_from":"synthetic_healthcare_data.csv","rows":(rows),"row_count":0,"truncated":false}
  Set stmt=##class(%SQL.Statement).%New()
  Set sc=stmt.%Prepare("SELECT TOP ? PatientCode,Age,Gender,BMI,SystolicPressure,DiastolicPressure,CholesterolLevel,Smoker,Diabetic,Diagnosis,TreatmentCost,AdmissionDate,DischargeDate,Outcome FROM MCPData_Data.Patient WHERE Diagnosis LIKE ? AND CAST(Diabetic AS VARCHAR) LIKE ? AND CAST(Smoker AS VARCHAR) LIKE ? AND Age BETWEEN ? AND ? ORDER BY PatientCode")
  If $$$ISERR(sc) Quit {"error":($SYSTEM.Status.GetErrorText(sc))}
  Set rs=stmt.%Execute(limit,diagnosisPattern,diabeticFilter,smokerFilter,minimumAge,maximumAge)
  While rs.%Next() {
    Set patient={
      "patientCode":(rs.PatientCode),
      "age":(rs.Age),
      "gender":(rs.Gender),
      "bmi":(rs.BMI),
      "bloodPressure":(rs.SystolicPressure_"/"_rs.DiastolicPressure),
      "cholesterol":(rs.CholesterolLevel),
      "smoker":(rs.Smoker),
      "diabetic":(rs.Diabetic),
      "diagnosis":(rs.Diagnosis),
      "treatmentCost":(rs.TreatmentCost),
      "admissionDate":($ZDATE(rs.AdmissionDate,3)),
      "dischargeDate":($ZDATE(rs.DischargeDate,3)),
      "outcome":(rs.Outcome)
    }
    Do rows.%Push(patient)
  }
  Do out.%Set("row_count",rows.%Size())
  Quit out
}

/// Method to read data from a specified global path, with a specified depth and limit. It returns the data in a structured format, limited by the specified limit.
Method ReadGlobalData(path As %String="^ERRORS",depth As %Integer=3,limit As %Integer=20) As %DynamicObject [ WebMethod ]
{
  Set rows=[]
  Set out={"rows":(rows),"count":0,"truncated":false}
  If path'="^ERRORS" Quit {"error":"Only ^ERRORS global is allowed"}
  If depth<1 Set depth=1
  If depth>3 Set depth=3
  If limit<1 Set limit=1
  If limit>50 Set limit=50
  Set root="^ERRORS"
  Set ref=root
  Set current=$QUERY(@ref)
  While current'="",$EXTRACT(current,1,$LENGTH(root))=root,rows.%Size()<limit {
    If $QLENGTH(current)<=depth {
      Do rows.%Push({"reference":(current),"value":($GET(@current))})
    }
    Set current=$QUERY(@current)
  }
  Do out.%Set("count",rows.%Size())
  If current'="",$EXTRACT(current,1,$LENGTH(root))=root {
    Do out.%Set("truncated","true")
  }
  Quit out
}

/// Method to retrieve the largest globals in the current namespace. It returns a list of globals sorted by size, limited by the specified limit.
Method LargestGlobals(limit As %Integer=10) As %DynamicObject [ WebMethod ]
{
  If limit<1 Set limit=1
  If limit>20 Set limit=20
  Set rows=[]
  Set out={"namespace":"MCP_EXAMPLE","unit":"MB","estimated":true,"rows":(rows)}
  Set list=##class(%ResultSet).%New("%SYS.GlobalQuery:NameSpaceList")
  Set sc=list.Execute("MCP_EXAMPLE","*",0,.unavailable,0,1,0)
  If $$$ISERR(sc) Quit {"error":($SYSTEM.Status.GetErrorText(sc))}
  While list.Next() {
    Set name=list.GetData(1) Continue:name["("
    Set size=##class(%ResultSet).%New("%SYS.GlobalQuery:NameSpaceSize")
    Set sc=size.Execute("^"_name,1,1)
    Set mb=0
    If $$$ISERR(sc) Continue
    While size.Next() {
      Set mb=mb+$SELECT(size.GetData(4)'="":+size.GetData(4),1:+size.GetData(3))
    }
    Set sizes(name)=mb
  }
  For rank=1:1:limit {
    Set name=""
    Set best=""
    Set bestMB=-1
    For  {
      Set name=$ORDER(sizes(name)) Quit:name=""
      If sizes(name)>bestMB Set best=name,bestMB=sizes(name)
    }
    Quit:best=""
    Do rows.%Push({"global":("^"_best),"sizeMB":(bestMB)}) Kill sizes(best)
  }
  Quit out
}

/// Method to retrieve recent application errors from the ^ERRORS global. It returns a list of errors with their timestamps, limited by the specified limit.
Method RecentApplicationErrors(limit As %Integer=10) As %DynamicObject [ WebMethod ]
{
  If limit<1 Set limit=1
  If limit>20 Set limit=20
  Set rows=[]
  Set out={"namespace":"MCP_EXAMPLE","redacted":true,"rows":(rows)}
  Set day=$ORDER(^ERRORS(""),-1)
  While day'="",rows.%Size()<limit {
    Set entry=$ORDER(^ERRORS(day,""),-1)
    While entry'="",rows.%Size()<limit {
      Set stamp=$GET(^ERRORS(day,entry,"*STACK",0,"V","$H"))
      Set error=$GET(^ERRORS(day,entry,"*STACK",0,"V","$ZE"))
      If error="" Set error=$GET(^ERRORS(day,entry,"*STACK",0,"V","Error"))
      Do rows.%Push({"id":(day_":"_entry),"timestamp":($SELECT(stamp'="":$ZDATETIME(stamp,3),1:$ZDATE(day,3))),"error":(error)})
      Set entry=$ORDER(^ERRORS(day,entry),-1)
    }
    Set day=$ORDER(^ERRORS(day),-1)
  }
  Quit out
}
}
