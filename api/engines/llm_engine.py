import os
import logging
from typing import AsyncGenerator, Optional
from transformers import AutoTokenizer, AutoModelForCausalLM, TextIteratorStreamer
import torch
import threading
import openai

logger = logging.getLogger(__name__)

class LLMEngine:
    def __init__(self):
        self.engine = os.getenv("LLM_ENGINE", "local")
        self.model_name = os.getenv("LLM_MODEL", "Qwen/Qwen2.5-1.5B-Instruct")
        
        if self.engine == "local":
            self._load_local_model()
        elif self.engine == "openai":
            openai.api_key = os.getenv("OPENAI_API_KEY")
            self.openai_model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
    
    def _load_local_model(self):
        """Load local transformers model"""
        try:
            logger.info(f"Loading model: {self.model_name}")
            self.tokenizer = AutoTokenizer.from_pretrained(self.model_name)
            self.model = AutoModelForCausalLM.from_pretrained(
                self.model_name,
                torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
                device_map="auto" if torch.cuda.is_available() else None,
                trust_remote_code=True
            )
            logger.info("Model loaded successfully")
        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            raise
    
    async def generate(self, prompt: str, max_length: int = 512) -> AsyncGenerator[str, None]:
        """Generate streaming response"""
        if self.engine == "openai":
            async for chunk in self._generate_openai(prompt):
                yield chunk
        else:
            async for chunk in self._generate_local(prompt, max_length):
                yield chunk
    
    async def _generate_openai(self, prompt: str) -> AsyncGenerator[str, None]:
        """Generate using OpenAI API"""
        try:
            response = await openai.ChatCompletion.acreate(
                model=self.openai_model,
                messages=[{"role": "user", "content": prompt}],
                stream=True,
                max_tokens=512,
                temperature=0.7
            )
            
            async for chunk in response:
                if chunk.choices[0].delta.content:
                    yield chunk.choices[0].delta.content
        except Exception as e:
            logger.error(f"OpenAI API error: {e}")
            yield f"Error: {str(e)}"
    
    async def _generate_local(self, prompt: str, max_length: int) -> AsyncGenerator[str, None]:
        """Generate using local model"""
        try:
            inputs = self.tokenizer.encode(prompt, return_tensors="pt")
            if torch.cuda.is_available():
                inputs = inputs.to("cuda")
            
            streamer = TextIteratorStreamer(self.tokenizer, skip_special_tokens=True)
            
            generation_kwargs = dict(
                input_ids=inputs,
                max_length=len(inputs[0]) + max_length,
                streamer=streamer,
                do_sample=True,
                temperature=0.7,
                pad_token_id=self.tokenizer.eos_token_id
            )
            
            thread = threading.Thread(target=self.model.generate, kwargs=generation_kwargs)
            thread.start()
            
            generated_text = ""
            for new_text in streamer:
                if prompt not in new_text:
                    generated_text += new_text
                    yield new_text
            
        except Exception as e:
            logger.error(f"Local generation error: {e}")
            yield f"Error: {str(e)}"

# Global instance
_llm_engine = None

def get_llm_engine() -> LLMEngine:
    global _llm_engine
    if _llm_engine is None:
        _llm_engine = LLMEngine()
    return _llm_engine