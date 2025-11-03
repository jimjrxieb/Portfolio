import os
import logging
from typing import AsyncGenerator
from transformers import AutoTokenizer, AutoModelForCausalLM, TextIteratorStreamer
import torch
import threading

logger = logging.getLogger(__name__)


class LLMEngine:
    """
    Unified LLM Engine supporting multiple providers:
    - Claude (Anthropic) - Recommended
    - OpenAI (GPT models)
    - Local (HuggingFace Transformers)
    """

    def __init__(self):
        self.provider = os.getenv("LLM_PROVIDER", "claude")  # claude, openai, or local
        self.model_name = os.getenv("LLM_MODEL")

        if self.provider == "local":
            if not self.model_name:
                self.model_name = "Qwen/Qwen2.5-1.5B-Instruct"
            self._load_local_model()
        elif self.provider == "claude":
            self.claude_api_key = os.getenv("CLAUDE_API_KEY")
            self.claude_model = self.model_name or "claude-3-5-sonnet-20241022"
            if not self.claude_api_key:
                logger.error("CLAUDE_API_KEY not set! Claude provider will fail.")
                raise ValueError("CLAUDE_API_KEY environment variable is required for Claude provider")
            logger.info(f"Using Claude provider with model: {self.claude_model}")
        elif self.provider == "openai":
            self.openai_api_key = os.getenv("OPENAI_API_KEY")
            self.openai_model = self.model_name or "gpt-4o-mini"
            if not self.openai_api_key:
                logger.error("OPENAI_API_KEY not set! OpenAI provider will fail.")
                raise ValueError("OPENAI_API_KEY environment variable is required for OpenAI provider")
            logger.info(f"Using OpenAI provider with model: {self.openai_model}")
        else:
            raise ValueError(f"Unknown LLM provider: {self.provider}. Use 'claude', 'openai', or 'local'")

    def _load_local_model(self):
        """Load local transformers model"""
        try:
            logger.info(f"Loading local model: {self.model_name}")
            self.tokenizer = AutoTokenizer.from_pretrained(
                self.model_name,
                revision="c6e32e2e8e1b2c7d3a4b5c6d7e8f9a0b1c2d3e4f"
            )
            self.model = AutoModelForCausalLM.from_pretrained(
                self.model_name,
                revision="c6e32e2e8e1b2c7d3a4b5c6d7e8f9a0b1c2d3e4f",
                torch_dtype=(
                    torch.float16 if torch.cuda.is_available() else torch.float32
                ),
                device_map="auto" if torch.cuda.is_available() else None,
                trust_remote_code=True,
            )
            logger.info(f"Local model loaded successfully: {self.model_name}")
        except Exception as e:
            logger.error(f"Failed to load local model {self.model_name}: {e}")
            raise

    async def generate(
        self, prompt: str, max_tokens: int = 1024
    ) -> AsyncGenerator[str, None]:
        """Generate streaming response from configured LLM provider"""
        if self.provider == "claude":
            async for chunk in self._generate_claude(prompt, max_tokens):
                yield chunk
        elif self.provider == "openai":
            async for chunk in self._generate_openai(prompt, max_tokens):
                yield chunk
        else:
            async for chunk in self._generate_local(prompt, max_tokens):
                yield chunk

    async def _generate_claude(self, prompt: str, max_tokens: int) -> AsyncGenerator[str, None]:
        """Generate using Claude (Anthropic) API with streaming"""
        try:
            from anthropic import AsyncAnthropic

            client = AsyncAnthropic(api_key=self.claude_api_key)

            logger.info(f"Calling Claude API with model: {self.claude_model}")

            async with client.messages.stream(
                model=self.claude_model,
                max_tokens=max_tokens,
                temperature=0.7,
                messages=[{"role": "user", "content": prompt}],
            ) as stream:
                async for text in stream.text_stream:
                    yield text

        except Exception as e:
            logger.error(f"Claude API error: {e}", exc_info=True)
            yield f"Error: Unable to generate response. {str(e)}"

    async def _generate_openai(self, prompt: str, max_tokens: int) -> AsyncGenerator[str, None]:
        """Generate using OpenAI API with streaming"""
        try:
            from openai import AsyncOpenAI

            client = AsyncOpenAI(api_key=self.openai_api_key)

            logger.info(f"Calling OpenAI API with model: {self.openai_model}")

            response = await client.chat.completions.create(
                model=self.openai_model,
                messages=[{"role": "user", "content": prompt}],
                stream=True,
                max_tokens=max_tokens,
                temperature=0.7,
            )

            async for chunk in response:
                if chunk.choices[0].delta.content:
                    yield chunk.choices[0].delta.content

        except Exception as e:
            logger.error(f"OpenAI API error: {e}", exc_info=True)
            yield f"Error: Unable to generate response. {str(e)}"

    async def _generate_local(
        self, prompt: str, max_tokens: int
    ) -> AsyncGenerator[str, None]:
        """Generate using local HuggingFace model with streaming"""
        try:
            logger.info(f"Generating with local model: {self.model_name}")

            inputs = self.tokenizer.encode(prompt, return_tensors="pt")
            if torch.cuda.is_available():
                inputs = inputs.to("cuda")

            streamer = TextIteratorStreamer(self.tokenizer, skip_special_tokens=True)

            generation_kwargs = dict(
                input_ids=inputs,
                max_length=len(inputs[0]) + max_tokens,
                streamer=streamer,
                do_sample=True,
                temperature=0.7,
                pad_token_id=self.tokenizer.eos_token_id,
            )

            thread = threading.Thread(
                target=self.model.generate, kwargs=generation_kwargs
            )
            thread.start()

            generated_text = ""
            for new_text in streamer:
                if prompt not in new_text:
                    generated_text += new_text
                    yield new_text

        except Exception as e:
            logger.error(f"Local generation error: {e}", exc_info=True)
            yield f"Error: Unable to generate response. {str(e)}"


# Global instance
_llm_engine = None


def get_llm_engine() -> LLMEngine:
    """Get or create global LLM engine instance"""
    global _llm_engine
    if _llm_engine is None:
        _llm_engine = LLMEngine()
    return _llm_engine
