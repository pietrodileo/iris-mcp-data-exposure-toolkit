# Exposing IRIS data through MCP with AI Hub: a practical toolkit with access controls

Connecting an AI agent to a database is useful, but it immediately raises another question: what should that agent be allowed to read?

For this project, I wanted to make that decision in the application code. An agent can search patient records using a few filters, inspect an approved global, and retrieve basic information about an IRIS namespace. It cannot submit its own SQL query or select another namespace.

I built the **MCP Data Exposure Toolkit** for the InterSystems [Community Bounty Program “Idea to Application” — Round 2](https://community.intersystems.com/post/community-bounty-program-idea-application-%E2%80%94-round-2-live), in response to the [MCP Data Exposure Toolkit idea (DPI-I-985)](https://ideas.intersystems.com/ideas/DPI-I-985). The request was for samples or templates that use AI Hub to discover and expose enterprise IRIS data through MCP, with controls around sensitive access.

My contribution is a runnable ObjectScript example covering SQL, globals, and namespace monitoring. It includes the tools, shared authorization and audit policies, Docker configuration, and client examples. There is no DocDB implementation in this version.

The source is available on [GitHub](https://github.com/pietrodileo/iris-mcp-data-exposure-toolkit). In this article, we'll run it and look at the code behind the examples.

## Table of contents

- [1. What the example exposes](#1-what-the-example-exposes)
- [2. How AI Hub fits into the project](#2-how-ai-hub-fits-into-the-project)
- [3. Running the toolkit](#3-running-the-toolkit)
- [4. From an ObjectScript method to an MCP tool](#4-from-an-objectscript-method-to-an-mcp-tool)
- [5. Searching patient records without accepting SQL](#5-searching-patient-records-without-accepting-sql)
- [6. Reading globals and inspecting the namespace](#6-reading-globals-and-inspecting-the-namespace)
- [7. Enforcing access rules](#7-enforcing-access-rules)
- [8. Recording tool execution](#8-recording-tool-execution)
- [9. Testing and adapting the example](#9-testing-and-adapting-the-example)
- [10. What this example does not solve](#10-what-this-example-does-not-solve)

## 1. What the example exposes

I chose synthetic healthcare records because they provide useful search criteria without putting real patient information in the repository. The project imports 500 records from the [Synthetic Healthcare Patient Records Dataset by dnation on Kaggle](https://www.kaggle.com/datasets/dnation/synthetic-healthcare-patient-records-dataset).

The persistent class `MCPData.Data.Patient` stores those records in `MCPData_Data.Patient`. During import, blood pressure is split into systolic and diastolic values, dates are converted to IRIS dates, and yes/no fields become Boolean values.

There are five tools:

| Tool | Purpose | Main restriction |
| --- | --- | --- |
| `ListResources` | Describe approved data sources and operations | Returns a fixed description, not the database catalog |
| `SearchPatients` | Filter synthetic patient records | Fixed SQL query; at most 50 rows |
| `ReadGlobalData` | Read global nodes | Only `^ERRORS`; depth 1–3 and at most 50 results |
| `LargestGlobals` | Report estimated global sizes | Only `MCP_EXAMPLE`; at most 20 results |
| `RecentApplicationErrors` | Return recent error summaries | Only ID, timestamp, and error text; at most 20 results |

This answers two parts of the community idea: helping an agent discover what is available, and giving it specific ways to access that data. Discovery describes the approved sources. It does not expose every table and global and leave the agent to decide what to use.

## 2. How AI Hub fits into the project

In my earlier article, [Model Context Protocol (MCP) with InterSystems IRIS — From Zero to Hero](https://community.intersystems.com/post/model-context-protocol-mcp-intersystems-iris-zero-hero), I explored MCP and a Python-based implementation. Here, the application tools are written in ObjectScript using AI Hub.

I obtained the Docker image through the instructions in the [InterSystems AI Hub Early Access Program repository](https://github.com/intersystems-community/ai-hub-eap). That repository also contains the documentation and samples I used as a starting point. This project depends on that early-access software; it is not an example for a standard IRIS image without AI Hub.

The application has two containers:

- `iris` runs the database, the ObjectScript tools, and the native MCP service.
- `mcp` runs the EAP's `iris-mcp-server` binary, which provides the Streamable HTTP transport for external clients.

The request path is:

```text
MCP client (on your machine)
  |
  | Streamable HTTP: http://localhost:8280/mcp/health-example
  | Docker maps host port 8280 to container port 8080
  v
iris-mcp-server (in the mcp container)
  |
  | Native connection to iris:1972 over the Compose network
  v
IRIS (in the iris container, namespace MCP_EXAMPLE)
  -> MCPData.Service.HealthExample    selects the ToolSet
  -> MCPData.ToolSet.HealthExample    attaches authorization and audit policies
  -> MCPData.Tools.HealthExample      executes the requested ObjectScript method
```

The endpoint path is configured in the bridge and registered in IRIS, where it selects the namespace and dispatch class. The bridge connects to the Compose service `iris`, not to `localhost`. Host port `9291` provides direct development access to IRIS port `1972`; MCP clients do not use it.

The second container uses the same project image, but it starts the bridge binary rather than another IRIS instance. Keeping the bridge separate makes its startup and logs easier to inspect.

## 3. Running the toolkit

You need Docker with Compose and the AI Hub EAP image. Follow the [EAP download instructions](https://github.com/intersystems-community/ai-hub-eap#accessing-the-software) and load the downloaded image into Docker. The project's `Dockerfile` currently references `2026.3.0AI.136.0`; check that its `FROM` line matches the image tag and architecture you downloaded.

Clone the project and prepare the configuration:

```bash
git clone https://github.com/pietrodileo/iris-mcp-data-exposure-toolkit.git
cd iris-mcp-data-exposure-toolkit
cp .env.example .env
```

Before starting, review the four credential variables in `.env`:

| Variables | Used for |
| --- | --- |
| `APP_USER`, `APP_PASS` | The MCP client's endpoint credentials |
| `WG_USER`, `WG_PASS` | The bridge's internal connection to IRIS |

The demo requires the existing `CSPSystem` gateway identity for `WG_USER`. The application user must be a different, dedicated account. Clients receive only the `APP_*` credentials.

```text
MCP client (on your machine)
  |
  | Streamable HTTP to localhost:8280/mcp/health-example
  | HTTP Basic authentication: APP_USER / APP_PASS
  | Application identity: mcp_reader (role MCPDataReader)
  v
iris-mcp-server (in the mcp container)
  |
  | Internal native connection to iris:1972
  | Gateway credentials: WG_USER / WG_PASS
  | Gateway identity: CSPSystem
  v
IRIS (in the iris container, namespace MCP_EXAMPLE)
```

Start the services in this order:

```bash
docker compose up -d --build --wait --wait-timeout 180 iris
docker compose exec iris iris session IRIS -U MCP_EXAMPLE '##class(MCPData.Setup).ConfigureUsers()'
docker compose up -d mcp
```

The middle command matters: Compose provides `.env` variables at runtime, so the endpoint user is configured after IRIS starts. `ConfigureUsers()` recreates `APP_USER` if it already exists. Do not point it at an account used by another application.

Alternatively, open the project in VS Code and run **MCP - Docker: Build and Start** from **Tasks: Run Task**.

The MCP endpoint is `http://localhost:8280/mcp/health-example`. Configure your client for Streamable HTTP with HTTP Basic authentication using `APP_USER` and `APP_PASS`. The [Developer Guide](https://github.com/pietrodileo/iris-mcp-data-exposure-toolkit/blob/main/dev.md) contains client configuration examples. Keep authorization headers out of commits and screenshots: Base64 encoding does not hide the password.

The Management Portal is available at `http://localhost:9292/csp/sys/UtilHome.csp`, with the demo defaults `_SYSTEM` / `SYS`. These are local development settings, not credentials for a deployed service.

If the Docker steps are unfamiliar, my [step-by-step guide to running IRIS with Docker](https://community.intersystems.com/post/running-intersystems-iris-docker-step-step-guide-part-1-basics-custom-dockerfile) covers the underlying setup.

A connected MCP client should discover all five tools. Here is the list in Mistral Vibe:

![Mistral Vibe displaying the five discovered MCP tools](pic/mistral_mcp_connected.png)

*The public tool names include the `mcp_health-example_` prefix. The ObjectScript method names below do not.*

## 4. From an ObjectScript method to an MCP tool

The main implementation is `src/MCPData/Tools/HealthExample.cls`. It extends `%AI.Tool`, and the exposed methods are `ClassMethod`s with the `WebMethod` keyword. None needs an object instance or per-client state. This also matters for connection management, which I'll cover in the testing section.

`ListResources` is a small, complete example:

```objectscript
Class MCPData.Tools.HealthExample Extends %AI.Tool
{
ClassMethod ListResources() As %DynamicObject [ WebMethod ]
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
}
```

Despite its name, `ListResources` is an MCP **tool** returning an application-level description. It is not an implementation of the MCP `resources/list` protocol method. Normal tool discovery and this description serve different purposes: one lists callable methods, while the other explains the data they expose.

The `synthetic` flag refers to the patient dataset. It should not be read as a guarantee that everything in an operational error global is synthetic.

Try asking:

> List all available resources and tools from the MCP server.

![Agent describing the approved SQL table, global, operations, and limits](pic/example_1.png)

The tools are grouped in `MCPData.ToolSet.HealthExample`. Its XML definition includes the tool class and attaches both policies:

```xml
<ToolSet Name="CareOutreachData">
  <Description>Read-only namespace monitoring and error inspection.</Description>
  <Policies>
    <Authorization Class="MCPData.Policy.Authorization"/>
    <Audit Class="MCPData.Policy.Audit"/>
  </Policies>
  <Include Class="MCPData.Tools.HealthExample"/>
</ToolSet>
```

Finally, the service points to that ToolSet:

```objectscript
Class MCPData.Service.HealthExample Extends %AI.MCP.Service
{
Parameter SPECIFICATION As STRING="MCPData.ToolSet.HealthExample";
}
```

This keeps the responsibilities separate: methods retrieve data, the ToolSet attaches shared policies, and the service selects what is exposed through the registered endpoint.

## 5. Searching patient records without accepting SQL

`SearchPatients` accepts diagnosis, diabetic and smoker status, an age range, and a result limit. There is no `sql` argument.

The first part of the method limits the requested row count:

```objectscript
If limit<1 Set limit=1
If limit>50 Set limit=50
```

It then prepares a fixed query and binds the filter values. Here is an excerpt from the implementation:

```objectscript
Set diagnosisPattern=$SELECT(diagnosis="":"%",1:diagnosis_"%")
Set diabeticFilter=$SELECT(diabetic="":"%",diabetic="Yes":1,diabetic="No":0,1:"invalid")
Set smokerFilter=$SELECT(smoker="":"%",smoker="Yes":1,smoker="No":0,1:"invalid")
If diabeticFilter="invalid"!(smokerFilter="invalid") Quit {"error":"diabetic and smoker must be Yes, No, or empty"}
```

The query has a fixed column list and table. Its filtering clause is:

```sql
WHERE Diagnosis LIKE ?
  AND CAST(Diabetic AS VARCHAR) LIKE ?
  AND CAST(Smoker AS VARCHAR) LIKE ?
  AND Age BETWEEN ? AND ?
ORDER BY PatientCode
```

The values are passed separately through `%Execute`:

```objectscript
Set rs=stmt.%Execute(limit+1,diagnosisPattern,diabeticFilter,smokerFilter,minimumAge,maximumAge)
```

The first parameter supplies `TOP ?` in the full query. Fetching one extra matching row lets the method detect truncation; that extra row is not included in the response. The tool returns at most `limit` rows, reports that limit as `applied_limit`, and sets `truncated` when more matches exist. `row_count` is the returned count, not the table size. The remaining parameters supply the filters. The agent can change values, but it cannot change the selected table, add joins, or replace the query with an update.

For an unfiltered request with `limit=1000`, the bundled 500-row dataset produces `row_count=50`, `applied_limit=50`, and `truncated=true`. By contrast, `truncated=false` means all matches for the current filters were returned—not that the whole table has been read. Omitting the limit uses the default of 20. These meanings are also in the tool description, so the client does not have to infer them from the result size.

The truncation flag is a JSON Boolean, not the string `"true"`; the global reader uses the same Boolean type. There is no pagination or cumulative read budget here: 50 is a per-call cap, not a guarantee that an agent cannot retrieve more data through multiple filtered calls.

Diagnosis uses `LIKE` with an appended `%`, so it is a prefix-style filter rather than exact equality. An empty diagnosis means no diagnosis restriction. Diabetic and smoker filters accept `Yes`, `No`, or an empty string.

For example:

> Find diabetic patients aged 60 or older with a Diabetes diagnosis. Return at most 10 records. Use the tools exposed by the MCP server.

The corresponding tool arguments can be expressed as:

```json
{
  "diagnosis": "Diabetes",
  "diabetic": "Yes",
  "minimumAge": 60,
  "limit": 10
}
```

![Agent displaying synthetic patient records matching diagnosis and age filters](pic/example_2.png)

*The screenshot shows the agent's presentation of the tool result. The filtering and row limit are implemented in IRIS, not in that presentation.*

## 6. Reading globals and inspecting the namespace

SQL is only one access pattern. `ReadGlobalData` demonstrates reading global nodes, but with an exact allowlist check before traversal:

```objectscript
If path'="^ERRORS" Quit {"error":"Only ^ERRORS global is allowed"}
If depth<1 Set depth=1
If depth>3 Set depth=3
If limit<1 Set limit=1
If limit>50 Set limit=50
Set root="^ERRORS"
```

The method walks nodes with `$QUERY`, checks their subscript depth with `$QLENGTH`, and returns reference/value pairs. The caller cannot provide an arbitrary global reference for evaluation. The limits bound returned rows and included depth; they are not a general execution-time budget for traversing a large global.

For a more specific task, `RecentApplicationErrors` builds a smaller response from the same global: an error ID, timestamp, and error text. It does not return the stack, local variables, usernames, or object data as separate fields.

That distinction is important when adapting the code. A bounded raw global read is still a raw read. Even an error summary can contain sensitive values inside the error message. Neither tool is a general-purpose anonymization service.

The other monitoring tool, `LargestGlobals`, uses `%SYS.GlobalQuery` to collect estimated sizes and returns the largest entries. The implementation excludes system globals and mapped subscript ranges. Its scope is fixed to `MCP_EXAMPLE`; there is no namespace parameter.

Try:

> Show me the 5 largest globals in the MCP_EXAMPLE namespace. Use the MCP server.

![Agent displaying estimated sizes for the five largest globals in MCP_EXAMPLE](pic/example_3.png)

## 7. Enforcing access rules

Tool descriptions help the agent choose a method, but they are not access controls. The project puts the rules in IRIS permissions, a shared authorization policy, and the methods themselves.

The endpoint requires the `MCPDataReader` role. Setup explicitly grants:

```sql
GRANT SELECT ON MCPData_Data.Patient TO MCPDataReader
```

SQL privileges are separate from database-resource permissions. The role also has read access to the project's code database and read/write access to its data database, where audit records are stored. Calling the tools “read-only” describes their data-retrieval operations; it does not mean the underlying role has no write capability.

`MCPData.Policy.Authorization` implements `%CanExecute`. This excerpt shows the tool allowlist:

```objectscript
Set allowlist=$LISTBUILD("ListResources","SearchPatients","ReadGlobalData","LargestGlobals","RecentApplicationErrors")
If $LISTFIND(allowlist,name)=0 {
  Quit ..Deny(name,call,"Tool is not allowlisted: "_name)
}
```

The policy also rejects paths other than `^ERRORS` for `ReadGlobalData` and clamps supplied limits and depths. Individual methods retain their own checks, including the stricter 20-result cap for monitoring.

Arguments can arrive as a dynamic object or as JSON text. The policy handles both and preserves that representation when forwarding adjusted limits. Malformed JSON, a non-object argument payload, or nested objects and arrays in the supported scalar fields are rejected before the tool runs. The `Deny()` helper records the rejected attempt as well as returning the access-denied status.

What happens when the user asks for something outside those rules?

| Request | What actually limits it |
| --- | --- |
| Run arbitrary SQL | No exposed tool accepts SQL text |
| Read `^MCPData.Care` | The authorization policy rejects the path; the method also checks it |
| Inspect the `USER` namespace | Monitoring has a fixed namespace and no namespace argument |
| Return 1,000 patient records | The requested limit is clamped to 50 |

For example, asking the agent to execute `SELECT * FROM MCPData_Data.Patient` produces an explanation that there is no general SQL tool:

![Agent explaining that arbitrary SQL is unavailable and suggesting SearchPatients](pic/not_allowed_1.png)

Reading a different global produces a tool access-denied error:

![Rejected read of a non-allowlisted global and explanation of the fixed namespace](pic/not_allowed_2.png)

These screenshots show two different situations. The global read reaches a server-side rejection. The namespace explanation describes an operation the tool does not offer. An agent saying “I cannot do that” is not, by itself, proof of enforcement; the policy and implementation are what make the restriction effective.

## 8. Recording tool execution

`MCPData.Policy.Audit` implements `%LogExecution` and persists records in `MCPData.Data.Audit`. Its basic fields are populated like this:

```objectscript
Set row=##class(MCPData.Data.Audit).%New()
Set toolName=call.%Get("name","unknown")
Set row.ToolName=$EXTRACT(toolName,1,120)
Set row.DurationMs=duration
Set row.StatusText=$EXTRACT($SYSTEM.Status.GetErrorText(status),1,500)
Set row.ResultCount=0
```

The full method adds tool-specific fields, such as patient search filters or global traversal parameters, then saves the record. The persistent class supplies the creation timestamp. It does not copy the full patient response into the audit table.

There is an EAP-specific detail here: the bridge supplies audit arguments as JSON text and wraps the output in `result_json`. The policy decodes these before reading filters or counting results, while also accepting dynamic objects from direct ObjectScript calls. Treating the JSON argument string as an object causes audit writes to fail for tools that inspect those arguments.

An administrator can inspect the records in the Management Portal, in `MCP_EXAMPLE`:

```sql
SELECT ID, AuditType, CreatedAt, ToolName
FROM MCPData_Data.Audit
```

![Management Portal query showing a timestamped ListResources audit record](pic/audit_example.png)

*This example shows a `ListResources` execution. Its `AuditType` is empty because that call does not use the SQL or global-specific audit category.*

`ResultCount` reads `row_count`, `count`, or the length of a `rows` array. The policy also records application-level `error` payloads and clips text to the database field limits. This EAP build does not call the execution audit policy for authorization denials, so the authorization policy records those rejected attempts itself. Authentication failures and requests that never reach the policies are outside this application audit. Audit filters and status text still deserve their own sensitive-data review.

Here is a fuller audit example. SQL calls record search filters; global calls record their scope and traversal settings. The failed patient search has a `StatusText` entry because its `diabetic` value was invalid. A valid search records its filters and returned count instead. Each invocation gets its own row, including repeated calls; fields unrelated to the tool remain empty.

![IRIS audit table showing SQL and global calls, returned counts, and a patient-filter validation error](pic/audit_example_2.png)

Authorization rejections have zero execution duration because the tool did not run. The explicit denial logging is needed for EAP build `2026.3.0AI.136.0`; recheck the callback behavior after an upgrade to avoid recording a denial twice if the framework starts auditing it automatically. The audit method also returns the persistence status rather than silently discarding a failed save.

## 9. Testing and adapting the example

The repository includes a Python smoke test that connects through the MCP endpoint, checks for the five expected tool names, and calls each tool with small inputs:

```bash
uv venv --python 3.12
source .venv/bin/activate
uv pip install -r requirements.txt
set -a
source .env
set +a
python test_mcp.py
```

It reports failures in connection, discovery, or invocation, including returned application error objects. This is useful for checking the full client-to-IRIS path without relying on how an agent chooses to call the tools. It is a smoke test, not a comprehensive security test suite.

### Policy and result regression tests

Two focused ObjectScript tests cover the fixes discussed above:

```bash
docker compose exec iris iris session IRIS -U MCP_EXAMPLE 'Write $SYSTEM.Status.GetErrorText(##class(MCPData.AuditTest).Run()),!'
docker compose exec iris iris session IRIS -U MCP_EXAMPLE 'Write $SYSTEM.Status.GetErrorText(##class(MCPData.Test).SearchPatientLimits()),!'
```

The audit test covers all five tools, string and object arguments, wrapped results, application errors, long fields, and authorization denials. Its test records are rolled back. Run it without concurrent MCP traffic because it checks the latest audit row. The patient test is read-only: it checks default and oversized limits, empty results, exact-boundary truncation, Boolean types, and stateless tool discovery.

### Keeping connection usage bounded

During testing, repeated client connections exposed another issue: the bridge's default pool size was 10, while the local demo license allowed eight users. Pool connections and license units are not interchangeable counts, but leaving the default unchanged was a poor fit for this setup.

The bridge configuration now makes the limits explicit. These are excerpts from the existing `[[iris]]` and `[mcp]` sections in `config_http.toml`:

```toml
[[iris]]
name = "health-example"
pool = { min = 1, max = 2 }
idle_timeout = "60s"
request_timeout = "60s"
max_sessions_per_auth_context = 2
max_age = "10m"
# Existing server and endpoints settings remain here.

[mcp]
transport = "http"
host = "0.0.0.0"
port = 8080
max_concurrent_requests = 2
```

The pool change alone was not enough. With instance methods, this EAP build retained CSP license connections after clients disconnected. Since the five tools need no instance state, I changed them to `ClassMethod`s; discovery now marks them as stateless. Authorization and auditing still apply through the ToolSet.

A local regression run made 127 tool calls, including concurrent clients, 30 reconnects, and three expected failures. It produced exactly 127 audit records and returned license usage to the diagnostic baseline, with no retained MCP user entry. That is evidence for this build and workload, not a capacity guarantee for every deployment. When testing your own changes, compare both `%SYSTEM.License:UserList` and `$SYSTEM.License.ShowSummary()` before and after the run; distinguish connection counts from license units.

Compose now checks readiness every 30 seconds instead of opening an IRIS terminal session every two seconds. That setting takes effect when the container is recreated, not merely restarted. The demo has no persistent database volumes, so preserve its data before rebuilding or recreating an existing IRIS container. If license exhaustion blocks administration, stop the bridge first; an in-place IRIS restart can recover the local demo but interrupts other clients. Repeated restarts are not a substitute for checking session usage.

### Adapting the tools

For another application, I would start by replacing one tool rather than making every database object discoverable:

1. Choose a concrete question the agent needs to answer and define the minimum output fields.
2. Implement a fixed query or a purpose-built global reader with typed inputs and result limits.
3. Update discovery, the authorization allowlist, and the required IRIS privileges together.
4. Test permitted calls, rejected paths, oversized limits, and what gets written to the audit table.

The same approach could be used for a DocDB example, but that would require a new implementation and its own access rules. The current SQL and global tools are starting points, not automatic adapters for every IRIS data model.

## 10. What this example does not solve

The [AI Hub EAP documentation](https://github.com/intersystems-community/ai-hub-eap#readme) identifies the software as pre-release and not intended for production. The toolkit also uses development credentials and HTTP Basic authentication over local HTTP. Compose publishes the Portal, MCP endpoint, and native IRIS port; the bridge does not isolate those other entry points.

Before using a similar design with real enterprise data, there is more work to do: TLS, network restrictions, credential management, privilege review, output minimization, and an audit retention policy. Patient-level or tenant-specific authorization is not implemented here, and raw error data requires particular care.

For the bounty idea, the result is a small example that can be inspected and changed: discover a defined set of data sources, call ObjectScript methods through AI Hub, enforce limits in IRIS, and record tool execution. The useful next step is to apply those patterns to a specific application question and decide exactly what its agent needs to see.

The [project README](https://github.com/pietrodileo/iris-mcp-data-exposure-toolkit#readme) contains the quick start, and the [Developer Guide](https://github.com/pietrodileo/iris-mcp-data-exposure-toolkit/blob/main/dev.md) covers the runtime configuration and client setup in more detail.
