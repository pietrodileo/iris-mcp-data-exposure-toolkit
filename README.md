# MCP Data Exposure Toolkit

Technical architecture, credentials, role configuration, and request flow: [`dev.md`](dev.md).

Secure templates exposing synthetic preventive-care outreach data and basic IRIS namespace health through MCP. One ToolSet demonstrates parameterized SQL, bounded global traversal, global-size monitoring, and redacted application-error summaries. No arbitrary SQL or global name is accepted.

## Why this fulfills the idea

The idea asks for reusable examples that use AI Hub to discover and expose enterprise IRIS data through MCP while controlling access to sensitive information. This project provides that complete path:

1. `%AI.Tool` methods define small, typed operations over IRIS data.
2. `%AI.ToolSet` groups those operations and makes their schemas discoverable.
3. `%AI.MCP.Service` publishes the ToolSet as an MCP endpoint.
4. `iris-mcp-server` exposes that native AI Hub service to any compatible MCP client or agent.
5. AI Hub authorization and audit policies control and record every tool call.

The project includes templates for IRIS data shapes:

- **SQL:** `SearchPatients` reads the imported 500-record healthcare dataset through one fixed parameterized query.
- **Globals:** `ReadGlobalData` traverses the `^ERRORS` global with bounded depth and result count.
- **Operational data:** `LargestGlobals` uses native `%SYS.GlobalQuery`, while `RecentApplicationErrors` returns a redacted view of the application error log.

These are examples, not a generic database gateway. A developer can copy a tool and replace its fixed query or allowlisted global with an enterprise-specific resource. The same ToolSet, policy, MCP service, and authentication structure remains reusable.

## Why the MCP bridge is required

The ObjectScript classes and `iris-mcp-server` have separate responsibilities. `%AI.MCP.Service` defines the native AI Hub service inside IRIS, connects it to the ToolSet, and keeps execution under IRIS authorization. It does not by itself provide the Streamable HTTP transport expected by external MCP clients.

`iris-mcp-server` is the AI Hub EAP binary that provides that transport. It accepts MCP requests over HTTP, connects to IRIS through the native protocol on port `1972`, and forwards calls to the registered `%AI.MCP.Service`. An equivalent transport component is therefore required for external clients; this project uses the official binary instead of implementing a custom gateway.

The binary runs in the separate `mcp` sidecar container. This is not a second IRIS instance and not an IRIS web application. The sidecar keeps bridge startup, logs, health, and restarts separate from the database process:

```text
MCP client
  -> http://localhost:8280/mcp/health-example
  -> iris-mcp-server in the mcp container (port 8080)
  -> IRIS service iris:1972
  -> MCPData.Service.HealthExample
  -> MCPData.ToolSet.HealthExample
```

The same binary could run in the IRIS container or on the host, but that would not remove the bridge. The sidecar is the smallest deployment that follows the official AI Hub template.

## Security model

Sensitive access is controlled at several layers:

- Clients connect through `iris-mcp-server` (the MCP bridge), not directly to IRIS. This isolates the native IRIS protocol port and provides a more secure, controlled transport layer.
- The endpoint user receives only the `MCPDataReader` role.
- The role receives `SELECT` only on `MCPData_Data.Patient`; database-resource access alone does not bypass IRIS SQL privileges.
- The authorization policy permits only five named tools.
- Clients cannot submit arbitrary SQL.
- Clients cannot choose an arbitrary global name.
- Query results, traversal depth, and monitoring results have hard limits.
- Monitoring stays inside the `MCP_EXAMPLE` namespace and cannot inspect the full IRIS instance.
- The audit policy records tool name, status, duration, and bounded result metadata.

This combination demonstrates both discovery and least-privilege exposure: an agent can discover what is available through MCP, but it can execute only the narrow operations deliberately published by the application.

## Run

A development `.env.example` is included locally, you can just rename to `.env` and launch the build and everything should work properly. 

**VS Code users:** Open this project folder and run the **MCP - Docker: Build and Start** task from **Tasks: Run Task**.

**Command line users:** Run from the project directory:

```bash
docker compose up -d --build
```

- MCP URL: <http://localhost:8280/mcp/health-example>
- IRIS Portal: <http://localhost:9292/csp/sys/UtilHome.csp> (default credentials: username `_SYSTEM`, password `SYS`).

The MCP URL is a protocol endpoint, not a browser user interface. Test it with VS Code or another MCP client using the configurations in [`dev.md`](dev.md).

## Exact local client connection

After running the build task, verify the IRIS container is running and the user defined in the `APP_USER` variable of `.env` has the `MCPDataReader` role.

A correct connection discovers these five public MCP tool names:

```text
mcp_health-example_ListResources
mcp_health-example_SearchPatients
mcp_health-example_ReadGlobalData
mcp_health-example_LargestGlobals
mcp_health-example_RecentApplicationErrors
```

An optional Python smoke test verifies authentication, checks that all five tools are discoverable, invokes every tool with small bounded inputs, and prints each structured response:

```bash
uv venv --python 3.12
source .venv/bin/activate
uv pip install -r requirements.txt
set -a
source .env
set +a
python test_mcp.py
```

Successful output reports five discovered tools followed by results for resource discovery, three synthetic Diabetes patients, the ^ERRORS global, the five largest namespace globals, and up to five recent application errors. The bridge exposes each tool with the `mcp_health-example_` prefix, and the test verifies those exact public MCP names. It exits with status `1` when credentials, discovery, or invocation fail.

VS Code users can also run **MCP - Docker: Cleanup Everything** or **MCP - Open: IRIS Management Portal** from **Tasks: Run Task**. Cleanup removes containers, networks, and project volumes.

## Exposed tools

- `ListResources`: declares exact read-only surface.
- `SearchPatients`: searches imported patient records by diagnosis, diabetic status, smoker status, and age range. It accepts scalar filters only and returns at most 50 rows.
- `ReadGlobalData`: reads the `^ERRORS` global with bounded depth and result count.
- `LargestGlobals`: top 1-20 globals visible in `MCP_EXAMPLE`, using native `%SYS.GlobalQuery`; system globals and mapped subscript ranges are excluded.
- `RecentApplicationErrors`: latest 1-20 `MCP_EXAMPLE` application errors from `^ERRORS`; returns only ID, timestamp, and error text. Stack, variables, usernames, and object data stay hidden.

Data is synthetic and contains patient codes, not names.


## Tool invocation prompts

| Tool | Prompt to invoke |
|-----------|---------------|
| `ListResources` | "List all available resources and tools from the MCP server." |
| `SearchPatients` | "Find diabetic patients aged 60 or older with a Diabetes diagnosis. Return at most 10 records. Use the tools exposed by the MCP server." |
| `ReadGlobalData` | "Read the ERRORS global at path ^ERRORS with depth 2 and limit 20. Use the MCP server tools." |
| `LargestGlobals` | "Show me the 5 largest globals in the MCP_EXAMPLE namespace. Use the MCP server." |
| `RecentApplicationErrors` | "Get the 10 most recent application errors from MCP_EXAMPLE. Use the tools exposed by the MCP server." |

Output supports operational outreach only. Monitoring is read-only and namespace-scoped, not an unrestricted whole-instance diagnostic API. Authorization and audit policies attach at ToolSet level.

## Agent scope examples

The following prompts demonstrate the **security boundaries** enforced by the MCP server. Agents can discover and use only the explicitly exposed tools and resources.

### ✅ Allowed: Discover and use exposed resources

| Capability | Example Prompt | Result |
|-----------|---------------|--------|
| List available tools | "List all available resources and tools from the MCP server." | Returns tool list with 5 discoverable tools |
| Query patient data | "Find diabetic patients aged 60 or older with a Diabetes diagnosis. Return at most 10 records. Use the tools exposed by the MCP server." | Returns filtered patient results (max 50 rows) |
| Read error log | "Get the 10 most recent application errors from MCP_EXAMPLE. Use the tools exposed by the MCP server." | Returns redacted errors (ID, timestamp, text only) |
| Read ^ERRORS global | "Read the ERRORS global at path ^ERRORS with depth 2 and limit 20. Use the MCP server tools." | Returns bounded global traversal |
| Monitor namespace | "Show me the 5 largest globals in the MCP_EXAMPLE namespace. Use the MCP server." | Returns top globals by size |

### ❌ Denied: Access to non-allowlisted resources

| Attempt | Example Prompt | Result |
|---------|---------------|--------|
| Arbitrary SQL | "Run SELECT * FROM MCPData_Data.Patient. Use the MCP server." | **Denied**: Tool not allowlisted (no arbitrary SQL) |
| Non-allowlisted global | "Read the ^MCPData.Care global. Use the MCP server tools." | **Denied**: Only ^ERRORS global is allowed |
| Cross-namespace access | "Show me the 5 largest globals in the USER namespace. Use the MCP server." | **Denied**: Monitoring stays inside MCP_EXAMPLE namespace |
| Unbounded results | "Find all patients without a limit. Use the MCP server." | **Denied**: Results clamped to max 50 rows |
| Arbitrary table access | "List all tables in the database. Use the MCP server." | **Denied**: No schema discovery tools exposed |

**Key principle**: Agents can discover what is available through MCP, but can execute only the narrow operations deliberately published by the application. All access is read-only, namespace-scoped, and bounded.

## Synthetic patient dataset

The project imports all 500 records from [`data/synthetic_healthcare_data.csv`](data/synthetic_healthcare_data.csv) during container installation. The source is [Synthetic Healthcare Patient Records Dataset by dnation on Kaggle](https://www.kaggle.com/datasets/dnation/synthetic-healthcare-patient-records-dataset).

Each record contains age, gender, BMI, blood pressure, cholesterol level, smoker and diabetic status, diagnosis, treatment cost, admission and discharge dates, and outcome. The data is synthetic and contains no real patient information, making it suitable for this open MCP example.

`MCPData.Data.Patient` is the only patient class and persistent IRIS table. It imports the CSV used by `SearchPatients`, separates blood pressure into systolic and diastolic numeric columns, and converts dates and yes/no fields to native IRIS types. This gives agents a realistic SQL discovery example without exposing protected health information.

Example request:

```text
Find diabetic patients aged 60 or older with a Diabetes diagnosis.
Return at most 10 records.

Do not search the local workspace or use other data sources.
Use the tools exposed by the MCP server.
```



- `WG_USER` and `WG_PASS` identify the bridge when it opens its internal native-protocol connection to IRIS on port `1972`. This project uses the built-in, privileged `CSPSystem` account. These infrastructure credentials stay inside the bridge and must never be configured in an MCP client.
- `APP_USER` and `APP_PASS` identify the MCP client at the published endpoint. `MCPData.Setup.ConfigureUsers()` creates this IRIS application user as `mcp_reader` and assigns only the `MCPDataReader` role.

```text
MCP client
  -- HTTP Basic with APP_USER and APP_PASS --> iris-mcp-server
  -- native connection with WG_USER and WG_PASS --> IRIS
```

Never reuse gateway credentials as endpoint credentials. Compromise of the limited application account must not expose the privileged bridge identity.

## Reuse

Adapt `SearchPatients` by replacing its fixed query and scalar filters. Adapt global exposure by changing exact allowlist, never by accepting arbitrary global names. Project `../my-first-agent` includes optional client configuration for this endpoint.
