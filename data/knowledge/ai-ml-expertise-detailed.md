# AI/ML Engineering Excellence: Technical Deep Dive

## Philosophy & Approach

**Practical AI Implementation**: Focus on solving real business problems rather than pursuing technology for its own sake. Every AI solution must deliver measurable value and operate reliably in production environments.

**Ethical AI Development**: Commitment to responsible AI practices, including bias detection, fairness assessment, transparency in decision-making, and privacy-preserving techniques.

**Production-First Mindset**: Design for scalability, maintainability, and operational excellence from day one. AI models must be robust, monitorable, and continuously improvable.

## Large Language Model Expertise

### Model Architecture & Training

**Hugging Face Ecosystem Mastery:**
```python
# Custom model fine-tuning pipeline
import torch
from transformers import (
    AutoTokenizer, 
    AutoModelForCausalLM,
    TrainingArguments,
    Trainer,
    DataCollatorForLanguageModeling
)
from datasets import Dataset
from peft import LoraConfig, get_peft_model, TaskType
import wandb

class LinkOpsModelTrainer:
    def __init__(self, base_model_name="microsoft/Phi-3-medium-4k-instruct"):
        self.base_model_name = base_model_name
        self.tokenizer = AutoTokenizer.from_pretrained(base_model_name)
        self.model = AutoModelForCausalLM.from_pretrained(
            base_model_name,
            torch_dtype=torch.float16,
            device_map="auto",
            trust_remote_code=True
        )
        
        # Add padding token if not present
        if self.tokenizer.pad_token is None:
            self.tokenizer.pad_token = self.tokenizer.eos_token
            
    def prepare_lora_model(self, task_type=TaskType.CAUSAL_LM):
        """Configure LoRA for efficient fine-tuning"""
        lora_config = LoraConfig(
            task_type=task_type,
            inference_mode=False,
            r=16,  # Rank of adaptation
            lora_alpha=32,  # LoRA scaling parameter
            lora_dropout=0.1,
            target_modules=["q_proj", "v_proj", "k_proj", "o_proj"]
        )
        
        self.model = get_peft_model(self.model, lora_config)
        return self.model
    
    def prepare_dataset(self, data_path, context_length=2048):
        """Prepare and tokenize training dataset"""
        with open(data_path, 'r', encoding='utf-8') as f:
            text_data = f.read()
        
        # Tokenize the dataset
        tokenized = self.tokenizer(
            text_data,
            truncation=True,
            padding=True,
            max_length=context_length,
            return_tensors="pt"
        )
        
        # Create Hugging Face dataset
        dataset = Dataset.from_dict({
            "input_ids": tokenized["input_ids"],
            "attention_mask": tokenized["attention_mask"]
        })
        
        return dataset
    
    def train_model(self, train_dataset, eval_dataset=None, output_dir="./trained_model"):
        """Fine-tune model with advanced training configuration"""
        
        # Initialize Weights & Biases for experiment tracking
        wandb.init(
            project="linkops-model-training",
            config={
                "base_model": self.base_model_name,
                "training_method": "LoRA",
                "dataset_size": len(train_dataset)
            }
        )
        
        training_args = TrainingArguments(
            output_dir=output_dir,
            num_train_epochs=3,
            per_device_train_batch_size=4,
            per_device_eval_batch_size=4,
            gradient_accumulation_steps=8,
            warmup_steps=100,
            max_steps=1000,
            learning_rate=2e-4,
            fp16=True,
            logging_steps=10,
            optim="adamw_torch",
            evaluation_strategy="steps" if eval_dataset else "no",
            eval_steps=50 if eval_dataset else None,
            save_steps=100,
            save_total_limit=3,
            load_best_model_at_end=True if eval_dataset else False,
            metric_for_best_model="eval_loss" if eval_dataset else None,
            greater_is_better=False,
            report_to="wandb",
            run_name=f"linkops-{self.base_model_name.split('/')[-1]}"
        )
        
        # Data collator for language modeling
        data_collator = DataCollatorForLanguageModeling(
            tokenizer=self.tokenizer,
            mlm=False,  # Not using masked language modeling
        )
        
        # Initialize trainer
        trainer = Trainer(
            model=self.model,
            args=training_args,
            train_dataset=train_dataset,
            eval_dataset=eval_dataset,
            data_collator=data_collator,
            tokenizer=self.tokenizer,
        )
        
        # Train the model
        trainer.train()
        
        # Save the final model
        trainer.save_model()
        self.tokenizer.save_pretrained(output_dir)
        
        return trainer

# Usage example for domain-specific fine-tuning
def train_property_management_model():
    trainer = LinkOpsModelTrainer()
    
    # Prepare LoRA model for efficient training
    model = trainer.prepare_lora_model()
    
    # Load domain-specific training data
    train_data = trainer.prepare_dataset("./data/zrs_management_procedures.txt")
    eval_data = trainer.prepare_dataset("./data/evaluation_set.txt")
    
    # Fine-tune the model
    trained_model = trainer.train_model(
        train_dataset=train_data,
        eval_dataset=eval_data,
        output_dir="./models/zrs_jade_assistant"
    )
    
    return trained_model
```

**Model Optimization Techniques:**
```python
# Quantization for deployment optimization
from transformers import BitsAndBytesConfig
import torch

def load_quantized_model(model_name, quantization_type="4bit"):
    """Load model with various quantization options"""
    
    if quantization_type == "4bit":
        quantization_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_compute_dtype=torch.float16,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_use_double_quant=True,
        )
    elif quantization_type == "8bit":
        quantization_config = BitsAndBytesConfig(
            load_in_8bit=True,
        )
    else:
        quantization_config = None
    
    model = AutoModelForCausalLM.from_pretrained(
        model_name,
        quantization_config=quantization_config,
        device_map="auto",
        torch_dtype=torch.float16,
        trust_remote_code=True
    )
    
    return model

# Knowledge distillation for creating smaller, faster models
class KnowledgeDistillationTrainer:
    def __init__(self, teacher_model, student_model, temperature=3.0, alpha=0.7):
        self.teacher_model = teacher_model
        self.student_model = student_model
        self.temperature = temperature
        self.alpha = alpha  # Weight for distillation loss
        
    def distillation_loss(self, student_logits, teacher_logits, labels):
        """Compute knowledge distillation loss"""
        # Soft targets from teacher
        teacher_probs = F.softmax(teacher_logits / self.temperature, dim=-1)
        student_log_probs = F.log_softmax(student_logits / self.temperature, dim=-1)
        
        # KL divergence loss
        distillation_loss = F.kl_div(
            student_log_probs, 
            teacher_probs, 
            reduction='batchmean'
        ) * (self.temperature ** 2)
        
        # Standard cross-entropy loss
        ce_loss = F.cross_entropy(student_logits, labels)
        
        # Combined loss
        total_loss = self.alpha * distillation_loss + (1 - self.alpha) * ce_loss
        return total_loss
```

### RAG (Retrieval-Augmented Generation) Systems

**Advanced RAG Pipeline Architecture:**
```python
import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer
import numpy as np
from typing import List, Dict, Optional
import logging
from dataclasses import dataclass

@dataclass
class RAGConfig:
    """Configuration for RAG pipeline"""
    embedding_model: str = "all-MiniLM-L6-v2"
    chunk_size: int = 1000
    chunk_overlap: int = 200
    max_context_length: int = 4000
    retrieval_top_k: int = 5
    rerank_top_k: int = 3
    similarity_threshold: float = 0.7

class AdvancedRAGEngine:
    def __init__(self, config: RAGConfig):
        self.config = config
        self.setup_embedding_model()
        self.setup_vector_database()
        self.setup_reranker()
        
    def setup_embedding_model(self):
        """Initialize sentence transformer for embeddings"""
        self.embedding_model = SentenceTransformer(self.config.embedding_model)
        self.embedding_dim = self.embedding_model.get_sentence_embedding_dimension()
        
    def setup_vector_database(self):
        """Initialize ChromaDB for vector storage"""
        self.chroma_client = chromadb.Client(Settings(
            chroma_db_impl="duckdb+parquet",
            persist_directory="./chroma_db"
        ))
        
        # Create or get collection
        self.collection = self.chroma_client.get_or_create_collection(
            name="linkops_knowledge",
            metadata={"hnsw:space": "cosine"}
        )
        
    def setup_reranker(self):
        """Initialize cross-encoder for reranking results"""
        from sentence_transformers.cross_encoder import CrossEncoder
        self.reranker = CrossEncoder('cross-encoder/ms-marco-MiniLM-L-6-v2')
    
    def chunk_document(self, text: str, metadata: Dict) -> List[Dict]:
        """Intelligent document chunking with semantic boundaries"""
        import re
        
        # Split on sentence boundaries
        sentences = re.split(r'(?<=[.!?])\s+', text)
        
        chunks = []
        current_chunk = ""
        current_length = 0
        
        for sentence in sentences:
            sentence_length = len(sentence.split())
            
            # If adding this sentence would exceed chunk size, start new chunk
            if current_length + sentence_length > self.config.chunk_size and current_chunk:
                chunks.append({
                    "text": current_chunk.strip(),
                    "metadata": {**metadata, "chunk_id": len(chunks)},
                    "word_count": current_length
                })
                
                # Start new chunk with overlap
                overlap_text = " ".join(current_chunk.split()[-self.config.chunk_overlap:])
                current_chunk = overlap_text + " " + sentence
                current_length = len(current_chunk.split())
            else:
                current_chunk += " " + sentence
                current_length += sentence_length
        
        # Add final chunk
        if current_chunk:
            chunks.append({
                "text": current_chunk.strip(),
                "metadata": {**metadata, "chunk_id": len(chunks)},
                "word_count": current_length
            })
        
        return chunks
    
    def add_documents(self, documents: List[Dict]):
        """Add documents to the knowledge base"""
        all_chunks = []
        
        for doc in documents:
            chunks = self.chunk_document(doc['text'], doc['metadata'])
            all_chunks.extend(chunks)
        
        # Generate embeddings
        texts = [chunk['text'] for chunk in all_chunks]
        embeddings = self.embedding_model.encode(texts, convert_to_numpy=True)
        
        # Add to ChromaDB
        self.collection.add(
            embeddings=embeddings.tolist(),
            documents=texts,
            metadatas=[chunk['metadata'] for chunk in all_chunks],
            ids=[f"doc_{i}" for i in range(len(all_chunks))]
        )
        
        logging.info(f"Added {len(all_chunks)} chunks to knowledge base")
    
    def hybrid_search(self, query: str, filter_metadata: Optional[Dict] = None) -> List[Dict]:
        """Combine vector similarity with keyword matching"""
        
        # Generate query embedding
        query_embedding = self.embedding_model.encode([query])
        
        # Vector similarity search
        results = self.collection.query(
            query_embeddings=query_embedding.tolist(),
            n_results=self.config.retrieval_top_k * 2,  # Retrieve more for reranking
            where=filter_metadata,
            include=['documents', 'metadatas', 'distances']
        )
        
        # Prepare candidates for reranking
        candidates = []
        for i, (doc, metadata, distance) in enumerate(zip(
            results['documents'][0], 
            results['metadatas'][0], 
            results['distances'][0]
        )):
            candidates.append({
                'text': doc,
                'metadata': metadata,
                'similarity_score': 1 - distance,  # Convert distance to similarity
                'rank': i
            })
        
        # Rerank using cross-encoder
        if len(candidates) > self.config.rerank_top_k:
            query_doc_pairs = [(query, candidate['text']) for candidate in candidates]
            rerank_scores = self.reranker.predict(query_doc_pairs)
            
            # Update candidates with rerank scores
            for candidate, rerank_score in zip(candidates, rerank_scores):
                candidate['rerank_score'] = float(rerank_score)
            
            # Sort by rerank score and take top k
            candidates = sorted(candidates, key=lambda x: x['rerank_score'], reverse=True)
            candidates = candidates[:self.config.rerank_top_k]
        
        # Filter by similarity threshold
        filtered_candidates = [
            c for c in candidates 
            if c['similarity_score'] >= self.config.similarity_threshold
        ]
        
        return filtered_candidates
    
    def generate_context(self, query: str, filter_metadata: Optional[Dict] = None) -> str:
        """Generate context for LLM from retrieved documents"""
        
        relevant_docs = self.hybrid_search(query, filter_metadata)
        
        if not relevant_docs:
            return "No relevant information found in the knowledge base."
        
        # Build context string
        context_parts = []
        total_length = 0
        
        for i, doc in enumerate(relevant_docs):
            doc_text = doc['text']
            doc_length = len(doc_text.split())
            
            # Check if adding this document would exceed context limit
            if total_length + doc_length > self.config.max_context_length:
                break
            
            # Add document with source attribution
            source_info = doc['metadata'].get('source', f'Document {i+1}')
            context_parts.append(f"[Source: {source_info}]\n{doc_text}")
            total_length += doc_length
        
        context = "\n\n".join(context_parts)
        
        logging.info(f"Generated context with {len(context_parts)} documents, {total_length} words")
        
        return context

# Usage example for property management RAG
def setup_property_management_rag():
    config = RAGConfig(
        chunk_size=800,
        chunk_overlap=150,
        retrieval_top_k=7,
        rerank_top_k=4,
        similarity_threshold=0.65
    )
    
    rag_engine = AdvancedRAGEngine(config)
    
    # Add property management documents
    documents = [
        {
            'text': open('./data/florida_housing_laws.txt').read(),
            'metadata': {'source': 'Florida Housing Laws', 'type': 'legal'}
        },
        {
            'text': open('./data/zrs_procedures.txt').read(),
            'metadata': {'source': 'ZRS Procedures', 'type': 'operational'}
        },
        {
            'text': open('./data/maintenance_protocols.txt').read(),
            'metadata': {'source': 'Maintenance Protocols', 'type': 'procedures'}
        }
    ]
    
    rag_engine.add_documents(documents)
    
    return rag_engine
```

### Voice AI & Speech Synthesis

**ElevenLabs Integration:**
```python
import requests
import base64
import io
import soundfile as sf
from typing import Optional, Dict, List
import asyncio
import aiohttp

class ElevenLabsVoiceEngine:
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://api.elevenlabs.io/v1"
        self.headers = {
            "Accept": "audio/mpeg",
            "Content-Type": "application/json",
            "xi-api-key": api_key
        }
        
    async def get_available_voices(self) -> List[Dict]:
        """Retrieve available voices from ElevenLabs"""
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{self.base_url}/voices",
                headers={"xi-api-key": self.api_key}
            ) as response:
                if response.status == 200:
                    data = await response.json()
                    return data.get('voices', [])
                else:
                    raise Exception(f"Failed to get voices: {response.status}")
    
    async def create_voice_from_samples(self, 
                                      name: str, 
                                      audio_files: List[str],
                                      description: str = "") -> str:
        """Create custom voice from audio samples"""
        
        # Prepare multipart form data
        data = aiohttp.FormData()
        data.add_field('name', name)
        data.add_field('description', description)
        
        # Add audio files
        for i, audio_file in enumerate(audio_files):
            with open(audio_file, 'rb') as f:
                data.add_field(
                    f'files',
                    f.read(),
                    filename=f'sample_{i}.mp3',
                    content_type='audio/mpeg'
                )
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.base_url}/voices/add",
                headers={"xi-api-key": self.api_key},
                data=data
            ) as response:
                if response.status == 200:
                    result = await response.json()
                    return result.get('voice_id')
                else:
                    error_text = await response.text()
                    raise Exception(f"Voice creation failed: {error_text}")
    
    async def synthesize_speech(self, 
                              text: str, 
                              voice_id: str,
                              model_id: str = "eleven_monolingual_v1",
                              voice_settings: Optional[Dict] = None) -> bytes:
        """Generate speech from text with advanced settings"""
        
        if voice_settings is None:
            voice_settings = {
                "stability": 0.75,
                "similarity_boost": 0.75,
                "style": 0.0,
                "use_speaker_boost": True
            }
        
        payload = {
            "text": text,
            "model_id": model_id,
            "voice_settings": voice_settings
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.base_url}/text-to-speech/{voice_id}",
                headers=self.headers,
                json=payload
            ) as response:
                if response.status == 200:
                    return await response.read()
                else:
                    error_text = await response.text()
                    raise Exception(f"Speech synthesis failed: {error_text}")
    
    async def synthesize_with_emotions(self,
                                     text: str,
                                     voice_id: str,
                                     emotion: str = "neutral",
                                     intensity: float = 0.5) -> bytes:
        """Advanced synthesis with emotional control"""
        
        # Emotion mapping to voice settings
        emotion_settings = {
            "neutral": {"stability": 0.75, "similarity_boost": 0.75, "style": 0.0},
            "excited": {"stability": 0.60, "similarity_boost": 0.80, "style": 0.3},
            "calm": {"stability": 0.85, "similarity_boost": 0.70, "style": -0.2},
            "authoritative": {"stability": 0.80, "similarity_boost": 0.85, "style": 0.1},
            "friendly": {"stability": 0.70, "similarity_boost": 0.75, "style": 0.2}
        }
        
        base_settings = emotion_settings.get(emotion, emotion_settings["neutral"])
        
        # Adjust settings based on intensity
        voice_settings = {
            "stability": base_settings["stability"] * (1 + intensity * 0.2),
            "similarity_boost": base_settings["similarity_boost"],
            "style": base_settings["style"] * intensity,
            "use_speaker_boost": True
        }
        
        return await self.synthesize_speech(text, voice_id, voice_settings=voice_settings)

# Custom voice profile for Gojo character
class GojoVoiceProfile:
    def __init__(self, elevenlabs_engine: ElevenLabsVoiceEngine):
        self.engine = elevenlabs_engine
        self.voice_id = None  # Will be set after voice creation
        
    async def create_gojo_voice(self, reference_audio_files: List[str]):
        """Create Gojo's voice profile from reference audio"""
        self.voice_id = await self.engine.create_voice_from_samples(
            name="Gojo Portfolio Assistant",
            audio_files=reference_audio_files,
            description="Professional, confident AI assistant voice for portfolio presentation"
        )
        return self.voice_id
    
    async def speak_as_gojo(self, text: str, context: str = "professional") -> bytes:
        """Generate speech with Gojo's personality"""
        
        # Context-aware emotion mapping
        context_emotions = {
            "professional": "authoritative",
            "explaining": "calm",
            "enthusiastic": "excited",
            "greeting": "friendly"
        }
        
        emotion = context_emotions.get(context, "neutral")
        
        return await self.engine.synthesize_with_emotions(
            text=text,
            voice_id=self.voice_id,
            emotion=emotion,
            intensity=0.6
        )
```

**Azure Speech Services Integration:**
```python
import azure.cognitiveservices.speech as speechsdk
from typing import Dict, List, Tuple
import json
import base64

class AzureSpeechEngine:
    def __init__(self, subscription_key: str, region: str):
        self.subscription_key = subscription_key
        self.region = region
        self.speech_config = speechsdk.SpeechConfig(
            subscription=subscription_key, 
            region=region
        )
        
    def synthesize_with_visemes(self, 
                               text: str, 
                               voice_name: str = "en-US-DavisNeural") -> Dict:
        """Generate speech with viseme data for lip-sync"""
        
        # Configure speech synthesizer
        self.speech_config.speech_synthesis_voice_name = voice_name
        
        # Create synthesizer
        synthesizer = speechsdk.SpeechSynthesizer(
            speech_config=self.speech_config,
            audio_config=None  # No audio output, we'll capture the data
        )
        
        # Configure viseme events
        viseme_data = []
        
        def viseme_received(evt):
            viseme_data.append({
                "audio_offset": evt.audio_offset / 10000,  # Convert to milliseconds
                "viseme_id": evt.viseme_id,
                "phoneme": evt.viseme_id,  # Map to phoneme if needed
                "timestamp": evt.audio_offset / 10000
            })
        
        # Subscribe to viseme events
        synthesizer.viseme_received.connect(viseme_received)
        
        # Synthesize speech
        result = synthesizer.speak_text_async(text).get()
        
        if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
            # Convert audio to base64
            audio_base64 = base64.b64encode(result.audio_data).decode('utf-8')
            
            return {
                "audio_base64": audio_base64,
                "visemes": viseme_data,
                "duration_ms": len(result.audio_data) / 32,  # Approximate duration
                "voice": voice_name,
                "sample_rate": 16000
            }
        else:
            raise Exception(f"Speech synthesis failed: {result.reason}")
    
    def create_ssml_with_emotions(self, 
                                 text: str, 
                                 voice_name: str,
                                 emotion: str = "neutral",
                                 intensity: str = "medium") -> str:
        """Create SSML with emotional markup"""
        
        ssml = f"""
        <speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" 
               xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="en-US">
            <voice name="{voice_name}">
                <mstts:express-as style="{emotion}" styledegree="{intensity}">
                    {text}
                </mstts:express-as>
            </voice>
        </speak>
        """
        return ssml
```

### MCP (Model Context Protocol) Tools Development

**Custom MCP Tool Framework:**
```python
from typing import Any, Dict, List, Optional, Callable
import asyncio
import json
import logging
from dataclasses import dataclass
from abc import ABC, abstractmethod

@dataclass
class MCPToolResult:
    """Result of MCP tool execution"""
    success: bool
    data: Any
    error: Optional[str] = None
    metadata: Optional[Dict] = None

class MCPTool(ABC):
    """Abstract base class for MCP tools"""
    
    def __init__(self, name: str, description: str):
        self.name = name
        self.description = description
        
    @abstractmethod
    async def execute(self, **kwargs) -> MCPToolResult:
        """Execute the tool with given parameters"""
        pass
    
    @abstractmethod
    def get_schema(self) -> Dict:
        """Return JSON schema for tool parameters"""
        pass

class EmailAutomationTool(MCPTool):
    """MCP tool for email automation"""
    
    def __init__(self, smtp_config: Dict):
        super().__init__(
            name="send_email",
            description="Send automated emails with templates and personalization"
        )
        self.smtp_config = smtp_config
        
    async def execute(self, 
                     to_email: str,
                     subject: str,
                     template: str,
                     variables: Dict = None,
                     attachments: List[str] = None) -> MCPToolResult:
        """Send email with template processing"""
        
        try:
            # Import email libraries
            import smtplib
            from email.mime.text import MIMEText
            from email.mime.multipart import MIMEMultipart
            from email.mime.base import MIMEBase
            from email import encoders
            import os
            
            # Process template with variables
            if variables:
                for key, value in variables.items():
                    template = template.replace(f"{{{key}}}", str(value))
            
            # Create message
            msg = MIMEMultipart()
            msg['From'] = self.smtp_config['from_email']
            msg['To'] = to_email
            msg['Subject'] = subject
            
            # Attach body
            msg.attach(MIMEText(template, 'html'))
            
            # Add attachments if any
            if attachments:
                for file_path in attachments:
                    if os.path.exists(file_path):
                        with open(file_path, "rb") as attachment:
                            part = MIMEBase('application', 'octet-stream')
                            part.set_payload(attachment.read())
                            encoders.encode_base64(part)
                            part.add_header(
                                'Content-Disposition',
                                f'attachment; filename= {os.path.basename(file_path)}'
                            )
                            msg.attach(part)
            
            # Send email
            with smtplib.SMTP(self.smtp_config['smtp_server'], self.smtp_config['port']) as server:
                server.starttls()
                server.login(self.smtp_config['username'], self.smtp_config['password'])
                server.send_message(msg)
            
            return MCPToolResult(
                success=True,
                data={"message": "Email sent successfully", "recipient": to_email},
                metadata={"timestamp": asyncio.get_event_loop().time()}
            )
            
        except Exception as e:
            logging.error(f"Email sending failed: {str(e)}")
            return MCPToolResult(
                success=False,
                data=None,
                error=str(e)
            )
    
    def get_schema(self) -> Dict:
        return {
            "type": "object",
            "properties": {
                "to_email": {"type": "string", "format": "email"},
                "subject": {"type": "string"},
                "template": {"type": "string"},
                "variables": {"type": "object"},
                "attachments": {"type": "array", "items": {"type": "string"}}
            },
            "required": ["to_email", "subject", "template"]
        }

class DataAnalysisTool(MCPTool):
    """MCP tool for automated data analysis"""
    
    def __init__(self):
        super().__init__(
            name="analyze_data",
            description="Perform statistical analysis and generate insights from data"
        )
        
    async def execute(self,
                     data_source: str,
                     analysis_type: str = "descriptive",
                     filters: Dict = None,
                     export_format: str = "json") -> MCPToolResult:
        """Perform data analysis"""
        
        try:
            import pandas as pd
            import numpy as np
            from scipy import stats
            import matplotlib.pyplot as plt
            import seaborn as sns
            import io
            import base64
            
            # Load data based on source type
            if data_source.endswith('.csv'):
                df = pd.read_csv(data_source)
            elif data_source.endswith('.xlsx'):
                df = pd.read_excel(data_source)
            else:
                # Assume it's a SQL query or database connection
                # Implementation would depend on specific database
                raise ValueError("Unsupported data source format")
            
            # Apply filters if provided
            if filters:
                for column, condition in filters.items():
                    if 'operator' in condition and 'value' in condition:
                        op = condition['operator']
                        val = condition['value']
                        
                        if op == 'eq':
                            df = df[df[column] == val]
                        elif op == 'gt':
                            df = df[df[column] > val]
                        elif op == 'lt':
                            df = df[df[column] < val]
                        elif op == 'contains':
                            df = df[df[column].str.contains(val, na=False)]
            
            # Perform analysis based on type
            results = {}
            
            if analysis_type == "descriptive":
                results['summary'] = df.describe().to_dict()
                results['missing_values'] = df.isnull().sum().to_dict()
                results['data_types'] = df.dtypes.to_dict()
                
            elif analysis_type == "correlation":
                numeric_cols = df.select_dtypes(include=[np.number]).columns
                if len(numeric_cols) > 1:
                    corr_matrix = df[numeric_cols].corr()
                    results['correlation_matrix'] = corr_matrix.to_dict()
                    
                    # Generate correlation heatmap
                    plt.figure(figsize=(10, 8))
                    sns.heatmap(corr_matrix, annot=True, cmap='coolwarm', center=0)
                    plt.title('Correlation Matrix')
                    
                    # Convert plot to base64
                    img_buffer = io.BytesIO()
                    plt.savefig(img_buffer, format='png', dpi=300, bbox_inches='tight')
                    img_buffer.seek(0)
                    img_base64 = base64.b64encode(img_buffer.getvalue()).decode()
                    plt.close()
                    
                    results['heatmap'] = img_base64
                    
            elif analysis_type == "distribution":
                numeric_cols = df.select_dtypes(include=[np.number]).columns
                results['distributions'] = {}
                
                for col in numeric_cols:
                    col_data = df[col].dropna()
                    results['distributions'][col] = {
                        'mean': float(col_data.mean()),
                        'median': float(col_data.median()),
                        'std': float(col_data.std()),
                        'skewness': float(stats.skew(col_data)),
                        'kurtosis': float(stats.kurtosis(col_data))
                    }
            
            return MCPToolResult(
                success=True,
                data=results,
                metadata={
                    "rows_analyzed": len(df),
                    "columns_analyzed": len(df.columns),
                    "analysis_type": analysis_type
                }
            )
            
        except Exception as e:
            logging.error(f"Data analysis failed: {str(e)}")
            return MCPToolResult(
                success=False,
                data=None,
                error=str(e)
            )
    
    def get_schema(self) -> Dict:
        return {
            "type": "object",
            "properties": {
                "data_source": {"type": "string"},
                "analysis_type": {
                    "type": "string",
                    "enum": ["descriptive", "correlation", "distribution", "regression"]
                },
                "filters": {"type": "object"},
                "export_format": {
                    "type": "string",
                    "enum": ["json", "csv", "xlsx"],
                    "default": "json"
                }
            },
            "required": ["data_source"]
        }

class MCPToolOrchestrator:
    """Orchestrate multiple MCP tools"""
    
    def __init__(self):
        self.tools = {}
        self.execution_history = []
        
    def register_tool(self, tool: MCPTool):
        """Register a new MCP tool"""
        self.tools[tool.name] = tool
        logging.info(f"Registered MCP tool: {tool.name}")
        
    async def execute_tool(self, tool_name: str, **kwargs) -> MCPToolResult:
        """Execute a specific tool by name"""
        if tool_name not in self.tools:
            return MCPToolResult(
                success=False,
                data=None,
                error=f"Tool '{tool_name}' not found"
            )
        
        tool = self.tools[tool_name]
        
        # Validate parameters against schema
        schema = tool.get_schema()
        # Add parameter validation logic here
        
        # Execute tool
        result = await tool.execute(**kwargs)
        
        # Log execution
        self.execution_history.append({
            "tool": tool_name,
            "timestamp": asyncio.get_event_loop().time(),
            "success": result.success,
            "error": result.error
        })
        
        return result
    
    async def execute_workflow(self, workflow: List[Dict]) -> List[MCPToolResult]:
        """Execute a series of tools in sequence"""
        results = []
        context = {}
        
        for step in workflow:
            tool_name = step.get('tool')
            parameters = step.get('parameters', {})
            
            # Substitute context variables
            for key, value in parameters.items():
                if isinstance(value, str) and value.startswith('$'):
                    # Extract from previous results
                    ref_key = value[1:]  # Remove $ prefix
                    if ref_key in context:
                        parameters[key] = context[ref_key]
            
            # Execute tool
            result = await self.execute_tool(tool_name, **parameters)
            results.append(result)
            
            # Update context for next step
            if result.success and 'output_key' in step:
                context[step['output_key']] = result.data
            
            # Stop on failure if specified
            if not result.success and step.get('stop_on_failure', True):
                break
        
        return results

# Example usage for property management automation
def setup_property_management_mcp():
    orchestrator = MCPToolOrchestrator()
    
    # Register tools
    email_tool = EmailAutomationTool({
        'smtp_server': 'smtp.gmail.com',
        'port': 587,
        'from_email': 'noreply@zrsmanagement.com',
        'username': 'smtp_user',
        'password': 'smtp_password'
    })
    
    data_tool = DataAnalysisTool()
    
    orchestrator.register_tool(email_tool)
    orchestrator.register_tool(data_tool)
    
    return orchestrator
```

## Production Deployment & MLOps

### Model Serving & Scaling

**FastAPI Production Deployment:**
```python
from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
import asyncio
from typing import Optional, List, Dict
import logging
import time
from prometheus_client import Counter, Histogram, generate_latest
import uvicorn

# Metrics for monitoring
REQUEST_COUNT = Counter('model_requests_total', 'Total model requests')
REQUEST_DURATION = Histogram('model_request_duration_seconds', 'Request duration')
TOKEN_GENERATION = Histogram('tokens_generated_total', 'Tokens generated per request')

class ModelManager:
    """Manages model loading and inference"""
    
    def __init__(self):
        self.models = {}
        self.tokenizers = {}
        self.load_models()
    
    def load_models(self):
        """Load all required models"""
        models_config = {
            'property_management': {
                'path': './models/zrs_jade_assistant',
                'max_length': 2048,
                'device': 'cuda' if torch.cuda.is_available() else 'cpu'
            },
            'general': {
                'path': 'microsoft/Phi-3-mini-4k-instruct',
                'max_length': 4096,
                'device': 'cuda' if torch.cuda.is_available() else 'cpu'
            }
        }
        
        for model_name, config in models_config.items():
            logging.info(f"Loading model: {model_name}")
            
            tokenizer = AutoTokenizer.from_pretrained(config['path'])
            model = AutoModelForCausalLM.from_pretrained(
                config['path'],
                torch_dtype=torch.float16 if config['device'] == 'cuda' else torch.float32,
                device_map='auto' if config['device'] == 'cuda' else None
            )
            
            if config['device'] == 'cpu':
                model = model.to('cpu')
            
            self.tokenizers[model_name] = tokenizer
            self.models[model_name] = model
            
            logging.info(f"Model {model_name} loaded successfully")
    
    async def generate_response(self, 
                              model_name: str,
                              prompt: str,
                              max_new_tokens: int = 512,
                              temperature: float = 0.7,
                              top_p: float = 0.9) -> str:
        """Generate response using specified model"""
        
        if model_name not in self.models:
            raise ValueError(f"Model {model_name} not available")
        
        model = self.models[model_name]
        tokenizer = self.tokenizers[model_name]
        
        # Tokenize input
        inputs = tokenizer(prompt, return_tensors="pt")
        
        # Move to appropriate device
        device = next(model.parameters()).device
        inputs = {k: v.to(device) for k, v in inputs.items()}
        
        # Generate response
        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_new_tokens=max_new_tokens,
                temperature=temperature,
                top_p=top_p,
                do_sample=True,
                pad_token_id=tokenizer.eos_token_id
            )
        
        # Decode response
        response = tokenizer.decode(
            outputs[0][inputs['input_ids'].shape[1]:], 
            skip_special_tokens=True
        )
        
        return response.strip()

# Initialize model manager
model_manager = ModelManager()

# FastAPI app
app = FastAPI(
    title="LinkOps AI Model API",
    description="Production AI model serving for LinkOps applications",
    version="2.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request/Response models
class GenerationRequest(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=4000)
    model: str = Field(default="general", description="Model to use for generation")
    max_tokens: int = Field(default=512, ge=1, le=2048)
    temperature: float = Field(default=0.7, ge=0.1, le=2.0)
    top_p: float = Field(default=0.9, ge=0.1, le=1.0)

class GenerationResponse(BaseModel):
    response: str
    model_used: str
    tokens_generated: int
    processing_time_ms: float

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "models_loaded": list(model_manager.models.keys()),
        "timestamp": time.time()
    }

# Metrics endpoint
@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()

# Main generation endpoint
@app.post("/generate", response_model=GenerationResponse)
async def generate_text(request: GenerationRequest):
    """Generate text using AI models"""
    
    REQUEST_COUNT.inc()
    start_time = time.time()
    
    try:
        response = await model_manager.generate_response(
            model_name=request.model,
            prompt=request.prompt,
            max_new_tokens=request.max_tokens,
            temperature=request.temperature,
            top_p=request.top_p
        )
        
        processing_time = (time.time() - start_time) * 1000
        tokens_generated = len(response.split())
        
        REQUEST_DURATION.observe(time.time() - start_time)
        TOKEN_GENERATION.observe(tokens_generated)
        
        return GenerationResponse(
            response=response,
            model_used=request.model,
            tokens_generated=tokens_generated,
            processing_time_ms=processing_time
        )
        
    except Exception as e:
        logging.error(f"Generation failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Batch processing endpoint
@app.post("/generate/batch")
async def generate_batch(requests: List[GenerationRequest]):
    """Process multiple generation requests"""
    
    results = []
    
    # Process requests concurrently
    tasks = [
        model_manager.generate_response(
            model_name=req.model,
            prompt=req.prompt,
            max_new_tokens=req.max_tokens,
            temperature=req.temperature,
            top_p=req.top_p
        )
        for req in requests
    ]
    
    responses = await asyncio.gather(*tasks, return_exceptions=True)
    
    for i, (req, response) in enumerate(zip(requests, responses)):
        if isinstance(response, Exception):
            results.append({
                "index": i,
                "error": str(response),
                "success": False
            })
        else:
            results.append({
                "index": i,
                "response": response,
                "model_used": req.model,
                "success": True
            })
    
    return {"results": results}

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        workers=1,  # Single worker to avoid model loading issues
        reload=False,
        access_log=True
    )
```

### Model Monitoring & Performance

**Comprehensive MLOps Pipeline:**
```python
import mlflow
import mlflow.pytorch
from mlflow.tracking import MlflowClient
import wandb
import numpy as np
from typing import Dict, List, Tuple
import torch
import time
import psutil
import GPUtil
from dataclasses import dataclass
import json

@dataclass
class ModelMetrics:
    """Model performance metrics"""
    latency_ms: float
    throughput_tokens_per_sec: float
    memory_usage_gb: float
    gpu_utilization: float
    accuracy_score: float
    perplexity: float

class ModelMonitor:
    """Monitor model performance and quality"""
    
    def __init__(self, model_name: str, experiment_name: str):
        self.model_name = model_name
        self.experiment_name = experiment_name
        
        # Initialize MLflow
        mlflow.set_experiment(experiment_name)
        self.client = MlflowClient()
        
        # Initialize Weights & Biases
        wandb.init(
            project="linkops-model-monitoring",
            name=f"{model_name}-monitoring"
        )
        
        self.metrics_history = []
    
    def measure_performance(self, 
                          model: torch.nn.Module,
                          tokenizer,
                          test_prompts: List[str],
                          device: str = "cuda") -> ModelMetrics:
        """Measure comprehensive model performance"""
        
        model.eval()
        
        # Performance metrics
        latencies = []
        token_counts = []
        
        # Memory baseline
        torch.cuda.empty_cache() if device == "cuda" else None
        initial_memory = self._get_memory_usage()
        
        # Run inference on test prompts
        with torch.no_grad():
            for prompt in test_prompts:
                start_time = time.time()
                
                # Tokenize
                inputs = tokenizer(prompt, return_tensors="pt").to(device)
                
                # Generate
                outputs = model.generate(
                    **inputs,
                    max_new_tokens=256,
                    do_sample=True,
                    temperature=0.7
                )
                
                # Measure latency
                latency = (time.time() - start_time) * 1000
                latencies.append(latency)
                
                # Count tokens
                generated_tokens = outputs.shape[1] - inputs['input_ids'].shape[1]
                token_counts.append(generated_tokens)
        
        # Calculate metrics
        avg_latency = np.mean(latencies)
        total_tokens = sum(token_counts)
        total_time = sum(latencies) / 1000  # Convert to seconds
        throughput = total_tokens / total_time if total_time > 0 else 0
        
        # Memory usage
        peak_memory = self._get_memory_usage()
        memory_usage = peak_memory - initial_memory
        
        # GPU utilization
        gpu_util = self._get_gpu_utilization()
        
        # Quality metrics (simplified)
        accuracy_score = self._calculate_accuracy(model, tokenizer, test_prompts)
        perplexity = self._calculate_perplexity(model, tokenizer, test_prompts)
        
        return ModelMetrics(
            latency_ms=avg_latency,
            throughput_tokens_per_sec=throughput,
            memory_usage_gb=memory_usage,
            gpu_utilization=gpu_util,
            accuracy_score=accuracy_score,
            perplexity=perplexity
        )
    
    def _get_memory_usage(self) -> float:
        """Get current memory usage in GB"""
        if torch.cuda.is_available():
            return torch.cuda.memory_allocated() / 1024**3
        else:
            return psutil.virtual_memory().used / 1024**3
    
    def _get_gpu_utilization(self) -> float:
        """Get GPU utilization percentage"""
        try:
            gpus = GPUtil.getGPUs()
            if gpus:
                return gpus[0].load * 100
        except:
            pass
        return 0.0
    
    def _calculate_accuracy(self, model, tokenizer, test_prompts: List[str]) -> float:
        """Calculate model accuracy on test set"""
        # Simplified accuracy calculation
        # In practice, this would use a labeled test set
        return 0.85  # Placeholder
    
    def _calculate_perplexity(self, model, tokenizer, test_prompts: List[str]) -> float:
        """Calculate model perplexity"""
        # Simplified perplexity calculation
        total_loss = 0
        total_tokens = 0
        
        model.eval()
        with torch.no_grad():
            for prompt in test_prompts[:10]:  # Sample for efficiency
                inputs = tokenizer(prompt, return_tensors="pt")
                if torch.cuda.is_available():
                    inputs = {k: v.cuda() for k, v in inputs.items()}
                
                outputs = model(**inputs, labels=inputs['input_ids'])
                loss = outputs.loss.item()
                tokens = inputs['input_ids'].shape[1]
                
                total_loss += loss * tokens
                total_tokens += tokens
        
        avg_loss = total_loss / total_tokens if total_tokens > 0 else float('inf')
        perplexity = torch.exp(torch.tensor(avg_loss)).item()
        
        return perplexity
    
    def log_metrics(self, metrics: ModelMetrics, step: int):
        """Log metrics to MLflow and Weights & Biases"""
        
        metrics_dict = {
            "latency_ms": metrics.latency_ms,
            "throughput_tokens_per_sec": metrics.throughput_tokens_per_sec,
            "memory_usage_gb": metrics.memory_usage_gb,
            "gpu_utilization": metrics.gpu_utilization,
            "accuracy_score": metrics.accuracy_score,
            "perplexity": metrics.perplexity
        }
        
        # Log to MLflow
        with mlflow.start_run():
            for metric_name, value in metrics_dict.items():
                mlflow.log_metric(metric_name, value, step=step)
        
        # Log to Weights & Biases
        wandb.log(metrics_dict, step=step)
        
        # Store in history
        self.metrics_history.append({
            "step": step,
            "timestamp": time.time(),
            "metrics": metrics_dict
        })
    
    def detect_performance_drift(self, 
                                current_metrics: ModelMetrics,
                                threshold_percent: float = 10.0) -> Dict[str, bool]:
        """Detect performance drift from baseline"""
        
        if len(self.metrics_history) < 5:
            return {"drift_detected": False, "reason": "Insufficient history"}
        
        # Calculate baseline from recent history
        recent_metrics = self.metrics_history[-5:]
        baseline = {
            "latency_ms": np.mean([m["metrics"]["latency_ms"] for m in recent_metrics]),
            "throughput_tokens_per_sec": np.mean([m["metrics"]["throughput_tokens_per_sec"] for m in recent_metrics]),
            "accuracy_score": np.mean([m["metrics"]["accuracy_score"] for m in recent_metrics])
        }
        
        # Check for drift
        drift_results = {}
        
        # Latency drift (increase is bad)
        latency_change = ((current_metrics.latency_ms - baseline["latency_ms"]) / 
                         baseline["latency_ms"]) * 100
        drift_results["latency_drift"] = latency_change > threshold_percent
        
        # Throughput drift (decrease is bad)
        throughput_change = ((baseline["throughput_tokens_per_sec"] - current_metrics.throughput_tokens_per_sec) / 
                           baseline["throughput_tokens_per_sec"]) * 100
        drift_results["throughput_drift"] = throughput_change > threshold_percent
        
        # Accuracy drift (decrease is bad)
        accuracy_change = ((baseline["accuracy_score"] - current_metrics.accuracy_score) / 
                          baseline["accuracy_score"]) * 100
        drift_results["accuracy_drift"] = accuracy_change > threshold_percent
        
        drift_results["overall_drift"] = any(drift_results.values())
        
        return drift_results

# A/B Testing Framework
class ModelABTest:
    """A/B testing framework for model comparison"""
    
    def __init__(self, model_a_name: str, model_b_name: str):
        self.model_a_name = model_a_name
        self.model_b_name = model_b_name
        self.results = {"model_a": [], "model_b": []}
        
    def run_test(self, 
                 model_a, tokenizer_a,
                 model_b, tokenizer_b,
                 test_prompts: List[str],
                 evaluation_criteria: List[str]) -> Dict:
        """Run A/B test comparing two models"""
        
        results = {
            "model_a": {"name": self.model_a_name, "scores": {}},
            "model_b": {"name": self.model_b_name, "scores": {}},
            "comparison": {}
        }
        
        # Generate responses from both models
        responses_a = []
        responses_b = []
        
        for prompt in test_prompts:
            # Model A
            inputs_a = tokenizer_a(prompt, return_tensors="pt")
            with torch.no_grad():
                outputs_a = model_a.generate(**inputs_a, max_new_tokens=256)
            response_a = tokenizer_a.decode(outputs_a[0][inputs_a['input_ids'].shape[1]:], skip_special_tokens=True)
            responses_a.append(response_a)
            
            # Model B
            inputs_b = tokenizer_b(prompt, return_tensors="pt")
            with torch.no_grad():
                outputs_b = model_b.generate(**inputs_b, max_new_tokens=256)
            response_b = tokenizer_b.decode(outputs_b[0][inputs_b['input_ids'].shape[1]:], skip_special_tokens=True)
            responses_b.append(response_b)
        
        # Evaluate responses
        for criterion in evaluation_criteria:
            score_a = self._evaluate_responses(responses_a, criterion)
            score_b = self._evaluate_responses(responses_b, criterion)
            
            results["model_a"]["scores"][criterion] = score_a
            results["model_b"]["scores"][criterion] = score_b
            results["comparison"][criterion] = {
                "winner": "model_a" if score_a > score_b else "model_b",
                "difference": abs(score_a - score_b),
                "significant": abs(score_a - score_b) > 0.05  # 5% threshold
            }
        
        return results
    
    def _evaluate_responses(self, responses: List[str], criterion: str) -> float:
        """Evaluate responses based on criterion"""
        # Simplified evaluation - in practice, would use more sophisticated metrics
        if criterion == "coherence":
            # Check for coherent sentence structure
            scores = []
            for response in responses:
                sentences = response.split('.')
                coherence_score = len([s for s in sentences if len(s.split()) > 3]) / max(len(sentences), 1)
                scores.append(min(coherence_score, 1.0))
            return np.mean(scores)
        
        elif criterion == "relevance":
            # Check if response contains relevant keywords
            # This would be more sophisticated in practice
            return 0.8  # Placeholder
        
        elif criterion == "accuracy":
            # Domain-specific accuracy assessment
            return 0.85  # Placeholder
        
        return 0.0

# Usage example
def setup_model_monitoring():
    monitor = ModelMonitor("zrs_jade_assistant", "property_management_monitoring")
    
    # Load models for testing
    # model, tokenizer = load_model_and_tokenizer("./models/zrs_jade_assistant")
    
    # Test prompts
    test_prompts = [
        "What are the Florida housing laws regarding security deposits?",
        "How should we handle a maintenance request for a broken air conditioner?",
        "What is the process for evicting a tenant who is 60 days behind on rent?"
    ]
    
    # Measure performance
    # metrics = monitor.measure_performance(model, tokenizer, test_prompts)
    # monitor.log_metrics(metrics, step=1)
    
    # Check for drift
    # drift_results = monitor.detect_performance_drift(metrics)
    
    return monitor

This comprehensive AI/ML expertise enables the development and deployment of production-ready artificial intelligence systems that solve real business problems while maintaining the highest standards of performance, reliability, and ethical responsibility.