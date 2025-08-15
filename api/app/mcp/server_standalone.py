# data-dev:mcp-server
# Pure MCP server (stdio). Use when connecting via Claude Desktop or other MCP clients.
import json
import sys
from typing import Dict, Any, List

class MCPServer:
    def __init__(self, name: str):
        self.name = name
        self.tools = {}
    
    def add_tool(self, name: str, description: str, input_schema: Dict[str, Any]):
        """Add a tool definition"""
        self.tools[name] = {
            "name": name,
            "description": description,
            "inputSchema": input_schema
        }
    
    def handle_request(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """Handle MCP request"""
        method = request.get("method")
        
        if method == "tools/list":
            return {
                "tools": list(self.tools.values())
            }
        elif method == "tools/call":
            tool_name = request["params"]["name"]
            arguments = request["params"]["arguments"]
            return self.call_tool(tool_name, arguments)
        else:
            return {"error": f"Unknown method: {method}"}
    
    def call_tool(self, tool_name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Call a tool and return result"""
        if tool_name == "send_email":
            return self._send_email(arguments)
        elif tool_name == "generate_report":
            return self._generate_report(arguments)
        elif tool_name == "onboard":
            return self._onboard(arguments)
        elif tool_name == "work_order":
            return self._work_order(arguments)
        else:
            return {"error": f"Unknown tool: {tool_name}"}
    
    def _send_email(self, args: Dict[str, Any]) -> Dict[str, Any]:
        # TODO: call internal action (SMTP/Gmail/SendGrid)
        return {"content": {"status": "sent"}}
    
    def _generate_report(self, args: Dict[str, Any]) -> Dict[str, Any]:
        # TODO: run LangGraph/SQL and save to /data/uploads/reports
        return {"content": {"status": "ok", "url": "/uploads/reports/demo.pdf"}}
    
    def _onboard(self, args: Dict[str, Any]) -> Dict[str, Any]:
        return {"content": {"status": "created", "entity": args.get("entity")}}
    
    def _work_order(self, args: Dict[str, Any]) -> Dict[str, Any]:
        return {"content": {"status": "created", "ticket": "WO-12345"}}
    
    def run_stdio(self):
        """Run MCP server over stdio"""
        for line in sys.stdin:
            try:
                request = json.loads(line.strip())
                response = self.handle_request(request)
                print(json.dumps(response))
                sys.stdout.flush()
            except Exception as e:
                error_response = {"error": str(e)}
                print(json.dumps(error_response))
                sys.stdout.flush()

# Create server instance
server = MCPServer("linkops-jade")

# Declare tools
server.add_tool(
    "send_email",
    "Send an email to a recipient.",
    {
        "type": "object",
        "properties": {
            "to": {"type": "string", "format": "email"},
            "subject": {"type": "string"},
            "body_markdown": {"type": "string"}
        },
        "required": ["to", "subject", "body_markdown"]
    }
)

server.add_tool(
    "generate_report",
    "Generate a report (delinquencies, workorders, rent-roll, compliance) for a period.",
    {
        "type": "object",
        "properties": {
            "kind": {"type": "string", "enum": ["delinquencies", "workorders", "rent-roll", "compliance"]},
            "period": {"type": "string"}
        },
        "required": ["kind", "period"]
    }
)

server.add_tool(
    "onboard",
    "Onboard a tenant or vendor.",
    {
        "type": "object",
        "properties": {
            "entity": {"type": "string", "enum": ["tenant", "vendor"]},
            "name": {"type": "string"},
            "email": {"type": "string", "format": "email"}
        },
        "required": ["entity", "name"]
    }
)

server.add_tool(
    "work_order",
    "Create a work order with priority.",
    {
        "type": "object",
        "properties": {
            "tenant_id": {"type": "string"},
            "description": {"type": "string"},
            "priority": {"type": "string", "enum": ["low", "normal", "high"]}
        },
        "required": ["tenant_id", "description"]
    }
)

if __name__ == "__main__":
    # stdio transport by default; clients like Claude Desktop can spawn this
    server.run_stdio()