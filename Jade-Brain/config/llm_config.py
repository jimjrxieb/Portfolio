"""
Jade-Brain LLM Configuration
Central configuration for all LLM interactions
"""

import os
from pathlib import Path

# LLM Configuration - SINGLE SOURCE OF TRUTH
LLM_PROVIDER = os.getenv("LLM_PROVIDER", "openai")
LLM_MODEL = os.getenv("LLM_MODEL", "gpt-4o-mini")
LLM_API_KEY = os.getenv("OPENAI_API_KEY", "")
LLM_API_BASE = os.getenv("LLM_API_BASE", "https://api.openai.com")

# Generation Parameters
DEFAULT_MAX_TOKENS = 512
DEFAULT_TEMPERATURE = 0.7
STREAM_RESPONSES = True

# Fallback Configuration
FALLBACK_MODEL = os.getenv("FALLBACK_MODEL", "Qwen/Qwen2.5-1.5B-Instruct")
USE_LOCAL_FALLBACK = os.getenv("USE_LOCAL_FALLBACK", "false").lower() == "true"

def get_llm_config() -> dict:
    """Get complete LLM configuration"""
    return {
        "provider": LLM_PROVIDER,
        "model": LLM_MODEL,
        "api_key": LLM_API_KEY,
        "api_base": LLM_API_BASE,
        "max_tokens": DEFAULT_MAX_TOKENS,
        "temperature": DEFAULT_TEMPERATURE,
        "stream": STREAM_RESPONSES,
        "fallback_model": FALLBACK_MODEL,
        "use_local_fallback": USE_LOCAL_FALLBACK
    }

def is_llm_configured() -> bool:
    """Check if LLM is properly configured"""
    if LLM_PROVIDER == "openai":
        return bool(LLM_API_KEY)
    return True  # Local models don't need API keys