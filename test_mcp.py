"""Smoke-test the Care Data Streamable HTTP MCP endpoint."""

import asyncio
import json
import os
import sys

import httpx2
from mcp import ClientSession
from mcp.client.streamable_http import streamable_http_client

MCP_URL = os.getenv("MCP_URL", "http://localhost:8280/mcp/health-example")
EXPECTED_TOOLS = {
    "mcp_health-example_LargestGlobals",
    "mcp_health-example_ListResources",
    "mcp_health-example_ReadGlobalData",
    "mcp_health-example_RecentApplicationErrors",
    "mcp_health-example_SearchPatients",
}
TOOL_CALLS = (
    ("mcp_health-example_ListResources", {}),
    (
        "mcp_health-example_SearchPatients",
        {"diagnosis": "Diabetes", "limit": 3},
    ),
    (
        "mcp_health-example_ReadGlobalData",
        {"path": "^ERRORS", "depth": 2, "limit": 10},
    ),
    ("mcp_health-example_LargestGlobals", {"limit": 5}),
    ("mcp_health-example_RecentApplicationErrors", {"limit": 5}),
)


def required_environment(name: str) -> str:
    """
    Get a required environment variable, raising an error if it is not set.
    """
    value = os.getenv(name, "")
    if not value:
        raise RuntimeError(f"{name} is required. Load the project .env first.")
    return value


def structured_result(result: object) -> object:
    payload = getattr(result, "structured_content", None)
    if payload is not None:
        return payload

    for content in getattr(result, "content", []):
        if content.type == "text":
            try:
                return json.loads(content.text)
            except json.JSONDecodeError:
                return content.text

    return None


async def test_endpoint() -> int:
    """
    Test the MCP endpoint by connecting, listing tools, and calling ListResources.
    """
    username = required_environment("APP_USER")
    password = required_environment("APP_PASS")
    timeout = httpx2.Timeout(30.0, read=300.0)

    async with httpx2.AsyncClient(
        auth=httpx2.BasicAuth(username, password),
        follow_redirects=True,
        timeout=timeout,
    ) as http_client:
        async with streamable_http_client(
            MCP_URL,
            http_client=http_client,
        ) as streams:
            async with ClientSession(streams[0], streams[1]) as session:
                await session.initialize()
                response = await session.list_tools()
                discovered = {tool.name for tool in response.tools}

                print(f"Connected to {MCP_URL}")
                print(f"Discovered {len(discovered)} tools:")
                for name in sorted(discovered):
                    print(f"- {name}")

                missing = EXPECTED_TOOLS - discovered
                if missing:
                    print(
                        "Missing expected tools: " + ", ".join(sorted(missing)),
                        file=sys.stderr,
                    )
                    return 1

                for tool_name, arguments in TOOL_CALLS:
                    result = await session.call_tool(tool_name, arguments)
                    if result.is_error:
                        print(
                            f"{tool_name} returned an MCP error.",
                            file=sys.stderr,
                        )
                        return 1

                    payload = structured_result(result)
                    print(f"\n{tool_name} succeeded:")
                    print(json.dumps(payload, indent=2, sort_keys=True))

                    if isinstance(payload, dict) and "error" in payload:
                        print(
                            f"{tool_name} returned an application error.",
                            file=sys.stderr,
                        )
                        return 1

                return 0


def main() -> int:
    try:
        return asyncio.run(test_endpoint())
    except Exception as error:
        print(f"MCP smoke test failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
