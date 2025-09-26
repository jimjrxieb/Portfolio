"""
Jade-Brain Response Generator
Combines RAG context with LLM to generate personality-consistent responses
"""

import openai
from typing import Dict, List, Optional
import logging
import sys
from pathlib import Path

# Add config to path
sys.path.append(str(Path(__file__).parent.parent / "config"))
from llm_config import get_llm_config, is_llm_configured
from personality_config import get_personality_config

from rag_interface import get_rag_interface

logger = logging.getLogger(__name__)

class ResponseGenerator:
    """Generates Jade responses using RAG context and LLM"""

    def __init__(self):
        self.llm_config = get_llm_config()
        self.personality_config = get_personality_config()
        self.rag = get_rag_interface()
        self._initialize_llm()

    def _initialize_llm(self):
        """Initialize LLM connection"""
        if not is_llm_configured():
            logger.warning("LLM not properly configured")
            return

        if self.llm_config["provider"] == "openai":
            openai.api_key = self.llm_config["api_key"]
            openai.api_base = self.llm_config["api_base"]
            logger.info(f"Initialized OpenAI with model: {self.llm_config['model']}")

    def generate_response(self, user_question: str) -> Dict:
        """Generate a complete response to user question"""
        try:
            # Step 1: Get relevant context from RAG
            context = self.rag.get_context(user_question, max_context_length=1500)

            # Step 2: Create system prompt
            system_prompt = self._create_system_prompt()

            # Step 3: Create user prompt with context
            user_prompt = self._create_user_prompt(user_question, context)

            # Step 4: Generate response from LLM
            response = self._call_llm(system_prompt, user_prompt)

            # Step 5: Post-process response
            formatted_response = self._format_response(response)

            return {
                "response": formatted_response,
                "context_used": bool(context and context.strip()),
                "rag_results": len(self.rag.search(user_question)),
                "model_used": self.llm_config["model"],
                "status": "success"
            }

        except Exception as e:
            logger.error(f"Response generation failed: {e}")
            return {
                "response": "I apologize, but I'm having trouble processing your question right now. Please try again.",
                "context_used": False,
                "rag_results": 0,
                "model_used": self.llm_config["model"],
                "status": "error",
                "error": str(e)
            }

    def _create_system_prompt(self) -> str:
        """Create system prompt defining Jade's personality"""
        personality = self.personality_config

        prompt = f"""You are {personality['name']}, {personality['role']}.

PERSONALITY:
- Honest and grounded about what's actually been built
- Self-aware about being a chatbot helping represent Jimmie
- Focused on practical, implemented solutions over buzzwords
- Learning-oriented - acknowledges ongoing development

IMPORTANT CONTEXT AWARENESS:
- You ARE the Jade chatbot that users are talking to
- This RAG system powering you is part of what Jimmie built
- Reference yourself naturally: "I'm powered by the RAG system Jimmie built"
- Point to concrete implementations, not theoretical expertise

AI/ML EXPERIENCE FOCUS:
- Jimmie's ACTUAL work: This RAG pipeline (sentence-transformers + ChromaDB)
- Currently learning and implementing: LangGraph, RPA integration, MCP
- Uses HuggingFace ecosystem for practical solutions
- Prefers efficient models (1.5B-7B params) over large ones
- NOT an AI expert - actively learning and building

RESPONSE STYLE:
- Be concise and direct
- Keep responses short unless asked for details
- Simple greetings: "Hello! I'm Jade, Jimmie's RAG-powered AI bot. Ask me about Jimmie's projects or experience."
- Avoid overstating experience or claiming expertise
- Reference actual tech stack when relevant: ChromaDB, sentence-transformers, FastAPI

HONEST POSITIONING:
- "Jimmie's learning AI/ML through hands-on projects like this chatbot"
- "He built this RAG system that powers me as a practical learning exercise"
- Avoid: "extensive experience", "expert-level", generic consultant language
- Keep simple for basic interactions, detailed only when asked

When provided with context from Jimmie's knowledge base, use it to give grounded, honest responses about what's been built."""

        return prompt

    def _create_user_prompt(self, question: str, context: str) -> str:
        """Create user prompt with question and RAG context"""
        if context and context.strip() and "No relevant information found" not in context:
            prompt = f"""Question: {question}

Relevant information from Jimmie's knowledge base:

{context}

Based on this information, please provide a helpful response as Jade, his AI assistant."""
        else:
            prompt = f"""Question: {question}

Please provide a helpful response as Jade, Jimmie's AI assistant, based on your knowledge of his work and expertise."""

        return prompt

    def _call_llm(self, system_prompt: str, user_prompt: str) -> str:
        """Call LLM to generate response"""
        if self.llm_config["provider"] == "openai":
            from openai import OpenAI
            client = OpenAI()
            response = client.chat.completions.create(
                model=self.llm_config["model"],
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                max_tokens=self.llm_config["max_tokens"],
                temperature=self.llm_config["temperature"]
            )
            return response.choices[0].message.content.strip()
        else:
            # Fallback or local model implementation would go here
            return "Local LLM not implemented yet. Please configure OpenAI API key."

    def _format_response(self, response: str) -> str:
        """Post-process and format the response"""
        # Basic cleanup
        response = response.strip()

        # Ensure it doesn't exceed format limits
        max_words = self.personality_config["format"]["max_length"]
        words = response.split()
        if len(words) > max_words:
            response = " ".join(words[:max_words]) + "..."

        return response

    def get_status(self) -> Dict:
        """Get response generator status"""
        return {
            "llm_configured": is_llm_configured(),
            "rag_available": self.rag.get_status()["available"],
            "model": self.llm_config["model"],
            "provider": self.llm_config["provider"]
        }

# Global instance
_response_generator = None

def get_response_generator() -> ResponseGenerator:
    """Get global response generator instance"""
    global _response_generator
    if _response_generator is None:
        _response_generator = ResponseGenerator()
    return _response_generator