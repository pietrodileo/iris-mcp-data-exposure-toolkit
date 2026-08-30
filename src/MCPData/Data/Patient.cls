Class MCPData.Data.Patient Extends %Persistent
{

Property PatientCode As %String(MAXLEN=20) [ Required ];

Property Age As %Integer;

Property Gender As %String(MAXLEN=20);

Property BMI As %Numeric(SCALE=1);

Property SystolicPressure As %Integer;

Property DiastolicPressure As %Integer;

Property CholesterolLevel As %Integer;

Property Smoker As %Boolean;

Property Diabetic As %Boolean;

Property Diagnosis As %String(MAXLEN=60);

Property TreatmentCost As %Numeric(SCALE=2);

Property AdmissionDate As %Date;

Property DischargeDate As %Date;

Property Outcome As %String(MAXLEN=30);

Index CodeIndex On PatientCode [ Unique ];

ClassMethod ImportCSV(path As %String="/home/irisowner/dev/data/synthetic_healthcare_data.csv") As %Status
{
  Set stmt=##class(%SQL.Statement).%New()
  Set sc=stmt.%Prepare("SELECT COUNT(*) AS N FROM MCPData_Data.Patient")
  If $$$ISERR(sc) Quit sc
  Set rs=stmt.%Execute()
  If rs.%Next(),rs.N=500 Quit $$$OK
  Set sc=stmt.%Prepare("DELETE FROM MCPData_Data.Patient")
  If $$$ISERR(sc) Quit sc
  Set rs=stmt.%Execute()
  If rs.%SQLCODE<0 Quit $$$ERROR($$$SQLError,rs.%SQLCODE,rs.%Message)
  Set file=##class(%Stream.FileCharacter).%New()
  Set file.Filename=path
  If file.AtEnd Quit $$$ERROR($$$GeneralError,"Patient CSV is empty or unavailable: "_path)
  Set header=$ZSTRIP(file.ReadLine(),"<>C")
  If header'="Patient_ID,Age,Gender,BMI,Blood_Pressure,Cholesterol_Level,Smoker,Diabetic,Diagnosis,Treatment_Cost,Admission_Date,Discharge_Date,Outcome" Quit $$$ERROR($$$GeneralError,"Unexpected patient CSV header")
  Set count=0
  While 'file.AtEnd {
    Set line=$ZSTRIP(file.ReadLine(),"<>C")
    Continue:line=""
    Set row=..%New()
    Set pressure=$PIECE(line,",",5)
    Set row.PatientCode=$PIECE(line,",",1)
    Set row.Age=+$PIECE(line,",",2)
    Set row.Gender=$PIECE(line,",",3)
    Set row.BMI=+$PIECE(line,",",4)
    Set row.SystolicPressure=+$ZSTRIP($PIECE(pressure,"/",1),"*W")
    Set row.DiastolicPressure=+$ZSTRIP($PIECE(pressure,"/",2),"*W")
    Set row.CholesterolLevel=+$PIECE(line,",",6)
    Set row.Smoker=($PIECE(line,",",7)="Yes")
    Set row.Diabetic=($PIECE(line,",",8)="Yes")
    Set row.Diagnosis=$PIECE(line,",",9)
    Set row.TreatmentCost=+$PIECE(line,",",10)
    Set row.AdmissionDate=$ZDATEH($PIECE(line,",",11),3)
    Set row.DischargeDate=$ZDATEH($PIECE(line,",",12),3)
    Set row.Outcome=$PIECE(line,",",13)
    Set sc=row.%Save()
    If $$$ISERR(sc) Quit
    Set count=count+1
  }
  If $$$ISERR(sc) Quit sc
  If count'=500 Quit $$$ERROR($$$GeneralError,"Expected 500 patient rows, imported "_count)
  Quit $$$OK
}
Storage Default
{
<Data name="PatientDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>PatientCode</Value>
</Value>
<Value name="3">
<Value>Age</Value>
</Value>
<Value name="4">
<Value>Gender</Value>
</Value>
<Value name="5">
<Value>BMI</Value>
</Value>
<Value name="6">
<Value>SystolicPressure</Value>
</Value>
<Value name="7">
<Value>DiastolicPressure</Value>
</Value>
<Value name="8">
<Value>CholesterolLevel</Value>
</Value>
<Value name="9">
<Value>Smoker</Value>
</Value>
<Value name="10">
<Value>Diabetic</Value>
</Value>
<Value name="11">
<Value>Diagnosis</Value>
</Value>
<Value name="12">
<Value>TreatmentCost</Value>
</Value>
<Value name="13">
<Value>AdmissionDate</Value>
</Value>
<Value name="14">
<Value>DischargeDate</Value>
</Value>
<Value name="15">
<Value>Outcome</Value>
</Value>
</Data>
<DataLocation>^MCPData.Data.PatientD</DataLocation>
<DefaultData>PatientDefaultData</DefaultData>
<IdLocation>^MCPData.Data.PatientD</IdLocation>
<IndexLocation>^MCPData.Data.PatientI</IndexLocation>
<StreamLocation>^MCPData.Data.PatientS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
