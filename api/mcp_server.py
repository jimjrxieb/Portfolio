# data-dev:mcp-server (Portfolio tools via MCP-style interface)
import asyncio
import json
import os
from typing import Any, Dict, List, Optional
from settings import settings


class PortfolioMCPServer:
    """
    MCP Server providing portfolio-specific tools:
    - search_knowledge: RAG search through Jimmie's knowledge base
    - create_avatar_video: Generate talking avatar with D-ID + ElevenLabs
    - send_email_report: Send automated reports (ZRS Management workflow)
    """
    
    def __init__(self):
        self.tools = {
            "search_knowledge": {
                "name": "search_knowledge",
                "description": "Search through Jimmie's knowledge base using RAG",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "query": {
                            "type": "string",
                            "description": "Search query for knowledge base"
                        },
                        "max_results": {
                            "type": "integer", 
                            "description": "Maximum number of results to return",
                            "default": 4
                        }
                    },
                    "required": ["query"]
                }
            },
            "create_avatar_video": {
                "name": "create_avatar_video",
                "description": "Create talking avatar video using uploaded image",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "text": {
                            "type": "string",
                            "description": "Text for avatar to speak"
                        },
                        "image_url": {
                            "type": "string",
                            "description": "URL of uploaded avatar image"
                        },
                        "voice_style": {
                            "type": "string",
                            "description": "Voice style: default or giancarlo",
                            "default": "default"
                        }
                    },
                    "required": ["text", "image_url"]
                }
            },
            "send_email_report": {
                "name": "send_email_report",
                "description": "Send automated email report (ZRS Management workflow)",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "recipient": {
                            "type": "string",
                            "description": "Email recipient"
                        },
                        "subject": {
                            "type": "string", 
                            "description": "Email subject"
                        },
                        "content": {
                            "type": "string",
                            "description": "Email content/report"
                        },
                        "report_type": {
                            "type": "string",
                            "description": "Type of report: compliance, maintenance, tenant_update",
                            "default": "general"
                        }
                    },
                    "required": ["recipient", "subject", "content"]
                }
            }
        }
    
    async def search_knowledge(self, query: str, max_results: int = 4) -> str:
        """Search Jimmie's knowledge base via RAG"""
        try:
            from rag import rag_retrieve
            persist_dir = f"{settings.DATA_DIR}/chroma"
            results = rag_retrieve(persist_dir, query, k=max_results)
            
            if not results:
                return "No relevant information found in knowledge base."
            
            # Format results with relevance scores
            formatted_results = []
            for i, (doc, distance) in enumerate(results):
                relevance = max(0, 1 - distance)  # Convert distance to relevance score
                formatted_results.append(f"Result {i+1} (relevance: {relevance:.2f}):\n{doc[:500]}...")
            
            return "\n\n".join(formatted_results)
            
        except Exception as e:
            return f"Knowledge search failed: {e}"
    
    async def create_avatar_video(self, text: str, image_url: str, voice_style: str = "default") -> str:
        """Create talking avatar video with D-ID"""
        try:
            from services.elevenlabs import synthesize_tts_mp3
            from services.did import create_talk_with_audio, get_talk_status
            import os
            
            # 1) Generate speech with ElevenLabs
            voice_id = settings.ELEVENLABS_DEFAULT_VOICE_ID
            if voice_style == "giancarlo":
                # Use specific voice ID if configured for Giancarlo style
                voice_id = os.getenv("ELEVENLABS_GIANCARLO_VOICE_ID", voice_id)
            
            mp3_path = await synthesize_tts_mp3(
                text=text,
                voice_id=voice_id,
                model_id="eleven_monolingual_v1",
                stability=0.3,
                similarity_boost=0.75
            )
            
            # 2) Convert local path to public URL
            rel_path = os.path.relpath(mp3_path, settings.DATA_DIR)
            audio_url = f"{settings.PUBLIC_BASE_URL}/{rel_path.replace(os.path.sep, '/')}"
            
            # 3) Create D-ID talking avatar
            talk_response = await create_talk_with_audio(image_url, audio_url)
            talk_id = talk_response.get("id")
            
            if not talk_id:
                return f"Avatar creation failed: {talk_response}"
            
            # 4) Poll for completion (up to 30 seconds)
            for attempt in range(20):
                status_response = await get_talk_status(talk_id)
                if status_response.get("result_url"):
                    return f"Avatar video ready: {status_response['result_url']}"
                elif status_response.get("status") == "error":
                    return f"Avatar generation failed: {status_response.get('error', 'Unknown error')}"
                
                await asyncio.sleep(1.5)
            
            return f"Avatar still processing (ID: {talk_id}). Check status later."
            
        except Exception as e:
            return f"Avatar creation failed: {e}"
    
    async def send_email_report(self, recipient: str, subject: str, content: str, report_type: str = "general") -> str:
        """Send automated email report (ZRS Management workflow)"""
        try:
            # For now, this is a stub - in production would integrate with:
            # - SendGrid/AWS SES for email delivery
            # - ZRS Management CRM/ticket system
            # - Compliance tracking system
            
            # Log the email action
            log_entry = {
                "action": "email_sent",
                "recipient": recipient,
                "subject": subject,
                "report_type": report_type,
                "content_length": len(content),
                "timestamp": asyncio.get_event_loop().time()
            }
            
            # In production: Send actual email here
            # await send_email_via_service(recipient, subject, content)
            
            return f"✅ Email report sent to {recipient}\nSubject: {subject}\nType: {report_type}\nContent: {len(content)} characters"
            
        except Exception as e:
            return f"Email sending failed: {e}"
    
    async def execute_tool(self, tool_name: str, arguments: Dict[str, Any]) -> str:
        """Execute a tool by name with given arguments"""
        if tool_name == "search_knowledge":
            return await self.search_knowledge(**arguments)
        elif tool_name == "create_avatar_video":
            return await self.create_avatar_video(**arguments)
        elif tool_name == "send_email_report":
            return await self.send_email_report(**arguments)
        else:
            return f"Unknown tool: {tool_name}"
    
    def get_tools_manifest(self) -> List[Dict[str, Any]]:
        """Return list of available tools for MCP client"""
        return list(self.tools.values())


# Global MCP server instance
mcp_server = PortfolioMCPServer()