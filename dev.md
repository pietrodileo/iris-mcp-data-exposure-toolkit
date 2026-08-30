# Developer Guide

## Runtime layout

This project has two containers:

- `iris` stores data, runs the native AI Hub classes, and registers the MCP application path and dispatch class.
- `mcp` runs the official `iris-mcp-server` binary. It provides the MCP transport and translates Streamable HTTP requests into calls to the native IRIS MCP service.

IRIS exposes its Management Portal on host port `9292` and SuperServer on `9291`. The MCP bridge exposes `http://localhost:8280/mcp/health-example`.

`%AI.MCP.Service` and `iris-mcp-server` are complementary, not alternative implementations. The ObjectScript service defines which ToolSet IRIS executes and applies IRIS security. The binary supplies the network-facing MCP transport required by VS Code, Claude Code, Codex, Cursor, and other external clients.

The bridge is a separate process, not a web application running in IRIS. Compose starts it with:

```yaml
entrypoint: ["iris-mcp-server"]
command: ["--config", "/home/irisowner/dev/config_http.toml", "run"]
```

It uses the same built project image only so the binary and configuration are already available. The `mcp` container does not start another IRIS instance.

Runtime path and ports:

```text
MCP client
  -> host localhost:8280
  -> mcp container port 8080
  -> iris container port 1972
  -> /mcp/health-example registration
  -> MCPData.Service.HealthExample
```

The `8280:8080` Compose mapping exposes the bridge to the host. Port `1972` remains the bridge-to-IRIS connection inside the Compose network; host port `9291` exists for development access and is not needed by local MCP clients.

An MCP transport component is required when external clients use this AI Hub EAP service. The official template provides `iris-mcp-server`; replacing it would mean building and maintaining an equivalent gateway. The binary could technically run inside the IRIS container or on the host, but it would still be required. A sidecar is used here because it keeps process lifecycle and logs separate without adding application code.

During image build, `App.Installer` creates namespace `MCP_EXAMPLE`, imports `src`, registers the native MCP application, imports the CSV, and seeds the allowlisted example global.

## Environment variables and two identities

Copy `.env.example` to `.env`. Four variables are required:

- `WG_USER` and `WG_PASS` belong to an IRIS user and authenticate `iris-mcp-server` when it opens its internal native-protocol connection to IRIS on port `1972`. This demo uses the built-in, privileged `CSPSystem` gateway identity.
- `APP_USER` and `APP_PASS` also belong to an IRIS user, but authenticate the MCP client at the `/mcp/health-example` endpoint. The default application identity is `mcp_reader`, limited to the `MCPDataReader` role.

These identities have different purposes and must not be reused. `config_http.toml` uses `WG_*` for its `server` connection and `APP_*` for its published endpoint. MCP clients receive only `APP_*`; `WG_*` stay inside the bridge container.

```text
MCP client
  -- Streamable HTTP Basic authentication: APP_USER / APP_PASS
  --> iris-mcp-server
  -- internal native connection: WG_USER / WG_PASS
  --> IRIS
```

Compose environment variables exist when containers run, not while the Docker image is compiled. For that reason, role and web-application definitions are installed during build, while `MCPData.Setup.ConfigureUsers()` is run after container startup to read credentials and create the endpoint user.

`ConfigureUsers()` verifies that the gateway identity is the existing `CSPSystem` account and rejects reuse of that name as `APP_USER`. It never changes the privileged gateway account. It recreates only the dedicated demo application user with the password from `APP_PASS` and assigns `MCPDataReader`, ensuring repeated setup runs remain aligned with `.env`.

## Role and endpoint configuration

`App.Installer.RegisterMCP()` runs in `%SYS` and creates role `MCPDataReader` when missing. Its resource grants are:

- `%DB_MCP_EXAMPLE_CODE:R` to execute compiled project code.
- `%DB_MCP_EXAMPLE_DATA:RW` to read exposed data and write bounded audit records.

The role does not grant general access to other namespaces or databases.

`MCPData.Setup.ConfigureUsers()` also grants `SELECT` on `MCPData_Data.Patient` to `MCPDataReader`. IRIS SQL privileges are separate from database-resource permissions, so this explicit table grant is required for the fixed `SearchPatients` query. No `INSERT`, `UPDATE`, `DELETE`, or privilege on another table is granted.

The installer registers `/mcp/health-example` with:

- namespace `MCP_EXAMPLE`;
- dispatch class `MCPData.Service.HealthExample`;
- password authentication;
- required match role `MCPDataReader`;
- application type `18`, required by the native MCP application;
- enabled status.

An authenticated request therefore needs both valid endpoint credentials and the required role before it reaches the AI Hub service.

## Native AI Hub classes

`MCPData.Service.HealthExample` extends `%AI.MCP.Service`. Its `SPECIFICATION` points to `MCPData.ToolSet.HealthExample`.

`MCPData.ToolSet.HealthExample` includes `MCPData.Tools.HealthExample` and attaches two policies:

- `MCPData.Policy.Authorization` permits only named tools, rejects arbitrary global paths, and clamps depth and result limits.
- `MCPData.Policy.Audit` stores tool name, duration, status, and bounded result count in `MCPData.Data.Audit`. It does not store credentials or full patient results.

Public `WebMethod` methods on `MCPData.Tools.HealthExample` become discoverable MCP tools:

- `ListResources`
- `SearchPatients`
- `LargestGlobals`
- `ReadGlobalData`
- `RecentApplicationErrors`

## Data lifecycle

`MCPData.Data.Patient` is the only patient class. `ImportCSV()` reads `data/synthetic_healthcare_data.csv`, validates its exact header, converts values to native IRIS types, and requires exactly 500 records. If 500 rows already exist, import is skipped. A partial extent is cleared and reloaded.

`SearchPatients` exposes a fixed parameterized SQL query over `MCPData_Data.Patient`. Clients can provide scalar filters but cannot supply SQL. Results are limited to 50.

`ReadGlobalData` accepts only the `^ERRORS` global and bounds traversal depth and row count.

`LargestGlobals` uses `%SYS.GlobalQuery` for estimated sizes of non-system globals visible in `MCP_EXAMPLE`. `RecentApplicationErrors` reads `^ERRORS` but returns only ID, timestamp, and error text. Stack frames, local variables, usernames, and object contents remain hidden.

## Request flow

1. MCP client sends a Streamable HTTP request to host port `8280` and authenticates to `iris-mcp-server` with `APP_USER` and `APP_PASS`.
2. Docker forwards the request to bridge port `8080`; the bridge connects to the `iris` service on port `1972` with `WG_USER` and `WG_PASS`.
3. IRIS resolves `/mcp/health-example` to `MCPData.Service.HealthExample` and checks `MCPDataReader`.
4. AI Hub discovers the ToolSet schema.
5. Authorization policy validates each call.
6. Tool executes its bounded read.
7. Audit policy records execution metadata.

## Configure an MCP client

Start the project and run `ConfigureUsers()` before connecting a client. The local
Streamable HTTP endpoint is:

```text
http://localhost:8280/mcp/health-example
```

It uses HTTP Basic authentication with `APP_USER` and `APP_PASS` from `.env`.

### Generate the authorization header

Create the Base64-encoded authorization value from your `.env` credentials:

```bash
# From the project directory, run:
source .env
echo -n "$APP_USER:$APP_PASS" | base64
```

Prepend `Basic ` to the output and include this complete value in the client configuration below. 
**If you change `APP_USER` or `APP_PASS` in `.env`, regenerate this value and update it in all client configs.**

Do not commit the generated value. Restart a desktop client after changing credentials so it picks up the new value. Stop and restart its MCP server after bridge restarts; use **Developer: Reload Window** if VS Code retains old tool discovery. The examples below configure the same MCP endpoint; the client does not need direct access to the IRIS SuperServer port.

### Python smoke test

The optional `test_mcp.py` client uses the official MCP Python SDK. It reads `APP_USER` and `APP_PASS`, connects through Streamable HTTP, requires all five project tools under their public `mcp_health-example_` names, and invokes each one with bounded example arguments. It never prints either credential.

```bash
uv venv --python 3.12
source .venv/bin/activate
uv pip install -r requirements.txt
set -a
source .env
set +a
python test_mcp.py
```

The MCP SDK requires Python 3.10 or newer. The local `.venv` avoids the macOS system Python and user site-packages; it is ignored by Git. `uv` downloads a managed Python 3.12 when no suitable interpreter is installed. Override `MCP_URL` only when the bridge is not available at its default local endpoint.

### VS Code

Create `.vscode/mcp.json` in the workspace with the authorization header included:

```json
{
  "servers": {
    "health-example": {
      "type": "http",
      "url": "http://localhost:8280/mcp/health-example",
      "headers": {
        "Authorization": "Basic bWNwX3JlYWRlcjptY3BfcmVhZGVyX3Rlc3RfMTIzNA=="
      }
    }
  }
}
```

Open the Command Palette, run **MCP: List Servers**, start `health-example`, and inspect its discovered tools. If it was already running, stop and start it so VS Code performs discovery again.

Reference: [VS Code MCP configuration](https://code.visualstudio.com/docs/agents/reference/mcp-configuration).

### Mistral

For Mistral Vibe, add this server to the project file `.vibe/config.toml` or the
user file `~/.vibe/config.toml`:

```toml
[[mcp_servers]]
name = "care_data"
transport = "streamable-http"
url = "http://localhost:8280/mcp/health-example"
headers = { Authorization = "Basic bWNwX3JlYWRlcjptY3BfcmVhZGVyX3Rlc3RfMTIzNA==" }
```

Start Vibe and use `/mcp care_data` to inspect the connection.

Mistral Le Chat/Work custom connectors run remotely and cannot reach
`localhost`. Deploy this MCP endpoint behind a publicly reachable HTTPS URL with
a valid TLS certificate, add a **Custom MCP Connector** from the Connectors page,
enter the deployed `/mcp/health-example` URL, and select Basic authentication when it
is detected. An administrator may need to enable the connector for the
workspace.

References: [Mistral Vibe MCP servers](https://docs.mistral.ai/vibe/code/cli/mcp-servers) and [Mistral Work MCP connectors](https://docs.mistral.ai/vibe/work/connectors/mcp-connectors).

### Claude Code

Register the endpoint for the current project from the project directory:

```bash
claude mcp add \
  --transport http \
  --scope project \
  --header "Authorization: Basic bWNwX3JlYWRlcjptY3BfcmVhZGVyX3Rlc3RfMTIzNA==" \
  health-example \
  http://localhost:8280/mcp/health-example
```

The equivalent project `.mcp.json` entry is:

```json
{
  "mcpServers": {
    "health-example": {
      "type": "http",
      "url": "http://localhost:8280/mcp/health-example",
      "headers": {
        "Authorization": "Basic bWNwX3JlYWRlcjptY3BfcmVhZGVyX3Rlc3RfMTIzNA=="
      }
    }
  }
}
```

Run `claude mcp get health-example` or use `/mcp` inside Claude Code to verify the
connection. Review a project-scoped `.mcp.json` before approving it because it
can define executable or remote tools.

Reference: [Claude Code MCP documentation](https://code.claude.com/docs/en/mcp).

### Codex

Add the following to `.codex/config.toml` for this project, or to
`~/.codex/config.toml` for all projects:

```toml
[mcp_servers.care_data]
url = "http://localhost:8280/mcp/health-example"
headers = { Authorization = "Basic bWNwX3JlYWRlcjptY3BfcmVhZGVyX3Rlc3RfMTIzNA==" }
enabled = true
required = true
default_tools_approval_mode = "prompt"
```

Run `codex mcp list` or use `/mcp` in the Codex TUI to confirm that `care_data` and its tools are available.

Reference: [Codex MCP configuration](https://developers.openai.com/codex/mcp/).

### Cursor

Create `.cursor/mcp.json` for project scope, or `~/.cursor/mcp.json` for global
scope:

```json
{
  "mcpServers": {
    "health-example": {
      "url": "http://localhost:8280/mcp/health-example",
      "headers": {
        "Authorization": "Basic bWNwX3JlYWRlcjptY3BfcmVhZGVyX3Rlc3RfMTIzNA=="
      }
    }
  }
}
```

Start Cursor, then
open **Cursor Settings > Tools & MCP** and enable `health-example`. Cursor Agent can
then discover and call its tools. Cursor CLI users can verify them with
`agent mcp list-tools health-example`.

Reference: [Cursor MCP documentation](https://cursor.com/docs/mcp).

### Networking notes

- `localhost:8280` works when the MCP client runs on the same host as Docker.
- From another container, use a reachable host name. On Docker Desktop this is
  commonly `host.docker.internal:8280`; a service on the same Compose network
  can use `mcp:8080`.
- Cloud clients require an HTTPS deployment. Do not publish this demo endpoint
  directly to the internet; place it behind normal TLS, network, secret rotation,
  and access-control infrastructure first.
- A successful connection exposes only the five allowlisted MCP tools. It does
  not grant arbitrary SQL, global, namespace, or Management Portal access.

## Development workflow

Open this folder directly in VS Code. Editor settings connect to `MCP_EXAMPLE`; launch settings debug `MCPData.Test` or attach to an IRIS process.

The repository includes `.env.example` as the committed template. The local
`.env` supplies Compose substitutions and is ignored by Git. If it is missing,
create it with `cp .env.example .env`, then change `APP_PASS` as needed.

Run:

```bash
docker compose up -d --build --wait --wait-timeout 180 iris
docker compose exec iris iris session IRIS -U MCP_EXAMPLE '##class(MCPData.Setup).ConfigureUsers()'
docker compose up -d mcp
docker compose exec iris iris session IRIS -U MCP_EXAMPLE '##class(MCPData.Test).Run()'
```

To expose another enterprise source, add a narrow `WebMethod`, add its name to the authorization allowlist, and extend the deterministic test. Do not accept arbitrary SQL, class names, global names, or unbounded limits.
