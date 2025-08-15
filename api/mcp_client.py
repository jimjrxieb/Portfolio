# data-dev:mcp-client (MCP-style client for enhanced LLM with portfolio tools)
import json
import asyncio
from typing import Dict, List, Any, Optional
import httpx
from settings import settings
from mcp_server import mcp_server


class PortfolioMCPClient:
    """
    MCP client that enhances LLM responses with portfolio-specific tools.
    Replaces basic HTTP LLM calls with tool-enhanced completions.
    """
    
    def __init__(self):
        self.tools = mcp_server.get_tools_manifest()
        self.server = mcp_server
    
    async def enhanced_chat_complete(
        self, 
        system_prompt: str, 
        user_message: str, 
        enable_tools: bool = True
    ) -> Dict[str, Any]:
        """
        Enhanced chat completion that can use portfolio tools via MCP.
        Returns both the LLM response and any tool results.
        """
        try:
            # 1) First, check if the user query suggests tool usage
            tool_suggestions = await self._analyze_tool_needs(user_message)
            
            tool_results = []
            enhanced_context = ""
            
            # 2) Execute suggested tools before LLM call
            if enable_tools and tool_suggestions:
                for tool_call in tool_suggestions:
                    result = await self.server.execute_tool(
                        tool_call["tool"], 
                        tool_call["arguments"]
                    )
                    tool_results.append({
                        "tool": tool_call["tool"],
                        "arguments": tool_call["arguments"], 
                        "result": result
                    })
                    
                    # Add tool results to context
                    enhanced_context += f"\n\nTool ({tool_call['tool']}) result:\n{result}"
            
            # 3) Enhanced system prompt with tool context
            if enhanced_context:
                system_prompt += enhanced_context
            
            # 4) Call LLM with enhanced context
            llm_response = await self._call_llm(system_prompt, user_message)
            
            return {
                "answer": llm_response,
                "tool_results": tool_results,
                "tools_used": [tr["tool"] for tr in tool_results]
            }
            
        except Exception as e:
            return {
                "answer": f"Enhanced chat failed: {e}",
                "tool_results": [],
                "tools_used": []
            }
    
    async def _analyze_tool_needs(self, user_message: str) -> List[Dict[str, Any]]:
        """
        Analyze user message to determine which tools might be helpful.
        Returns list of suggested tool calls.
        """
        suggestions = []
        msg_lower = user_message.lower()
        
        # Search knowledge for questions about Jimmie, experience, skills, etc.
        knowledge_triggers = [
            "what", "who", "how", "when", "where", "why", "tell me about",
            "experience", "skill", "project", "work", "background", "resume",
            "jimmie", "jade", "zrs", "devops", "mlops", "security", "portfolio"
        ]
        
        if any(trigger in msg_lower for trigger in knowledge_triggers):
            suggestions.append({
                "tool": "search_knowledge",
                "arguments": {"query": user_message, "max_results": 4}
            })
        
        # Avatar creation for specific requests
        avatar_triggers = [
            "create avatar", "make avatar", "generate video", "talk about",
            "avatar video", "speaking video", "talking head"
        ]
        
        if any(trigger in msg_lower for trigger in avatar_triggers):
            # Note: This would need image_url from a previous upload
            # For now, we'll skip auto-avatar creation in chat
            pass
        
        return suggestions
    
    async def _call_llm(self, system_prompt: str, user_message: str) -> str:
        """
        Call the LLM with OpenAI-compatible API.
        This is the same as the original llm_client.py logic.
        """
        payload = {
            "model": settings.LLM_MODEL_ID,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_message},
            ],
            "temperature": 0.2,
        }
        headers = {"Content-Type": "application/json"}
        if settings.LLM_API_KEY:
            headers["Authorization"] = f"Bearer {settings.LLM_API_KEY}"

        timeout = httpx.Timeout(60.0, connect=10.0)
        async with httpx.AsyncClient(base_url=str(settings.LLM_API_BASE), timeout=timeout) as client:
            r = await client.post("/v1/chat/completions", headers=headers, json=payload)
            r.raise_for_status()
            data = r.json()
            return data["choices"][0]["message"]["content"]
    
    async def create_avatar_with_text(
        self, 
        text: str, 
        image_url: str, 
        voice_style: str = "default"
    ) -> str:
        """
        Direct avatar creation tool call.
        """
        return await self.server.execute_tool("create_avatar_video", {
            "text": text,
            "image_url": image_url, 
            "voice_style": voice_style
        })
    
    async def search_knowledge_base(self, query: str, max_results: int = 4) -> str:
        """
        Direct knowledge search tool call.
        """
        return await self.server.execute_tool("search_knowledge", {
            "query": query,
            "max_results": max_results
        })
    
    async def send_email_report(
        self, 
        recipient: str, 
        subject: str, 
        content: str, 
        report_type: str = "general"
    ) -> str:
        """
        Direct email sending tool call.
        """
        return await self.server.execute_tool("send_email_report", {
            "recipient": recipient,
            "subject": subject,
            "content": content,
            "report_type": report_type
        })


# Global MCP client instance
mcp_client = PortfolioMCPClient()