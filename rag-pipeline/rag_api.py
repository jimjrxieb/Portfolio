"""
RAG Pipeline API
Jupyter notebook-based knowledge retrieval system
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict
import os
import chromadb
from datetime import datetime
import openai

app = FastAPI(
    title="RAG Pipeline API",
    description="Knowledge retrieval system with Jupyter notebooks",
    version="1.0.0",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://linksmlm.com", "http://localhost:5173", "http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
CHROMA_URL = os.getenv("CHROMA_URL", "http://chromadb:8000")
openai.api_key = os.getenv("GPT_API_KEY")
GPT_MODEL = os.getenv("GPT_MODEL", "gpt-4o-mini")


class QueryRequest(BaseModel):
    query: str
    context_type: Optional[str] = "general"  # devops, aiml, projects, general
    max_results: Optional[int] = 5


class QueryResponse(BaseModel):
    answer: str
    sources: List[Dict]
    context_used: str
    timestamp: datetime


class KnowledgeStatus(BaseModel):
    status: str
    collections: List[str]
    total_documents: int
    jupyter_url: str


@app.get("/health")
async def health_check():
    """Health check for RAG pipeline"""
    return {
        "status": "healthy",
        "service": "rag-pipeline",
        "chroma_url": CHROMA_URL,
        "model": GPT_MODEL,
        "jupyter_url": "http://localhost:8888",
        "timestamp": datetime.now(),
    }


@app.get("/status", response_model=KnowledgeStatus)
async def get_knowledge_status():
    """Get status of knowledge base and Jupyter"""
    try:
        # This would connect to ChromaDB to get actual status
        # For now, return mock data
        return KnowledgeStatus(
            status="active",
            collections=["portfolio", "devops", "aiml", "projects"],
            total_documents=0,  # Would query ChromaDB
            jupyter_url="http://localhost:8888/lab?token=portfolio-rag-2025",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Status check failed: {str(e)}")


@app.post("/query", response_model=QueryResponse)
async def query_knowledge(request: QueryRequest):
    """Query the knowledge base using RAG"""

    if not openai.api_key:
        raise HTTPException(status_code=500, detail="OpenAI API key not configured")

    try:
        # This would implement actual RAG retrieval
        # For now, provide structured responses based on query type

        context_responses = {
            "devops": "I specialize in DevSecOps practices including CI/CD pipelines, container orchestration with Kubernetes, Infrastructure as Code using Terraform, and security-first development approaches.",
            "aiml": "My AI/ML expertise includes implementing RAG systems, LLM integration and optimization, machine learning pipeline development, and working with vector databases for production deployments.",
            "projects": "Key projects include this AI-powered portfolio platform with microservices architecture, automated DevSecOps pipelines, and production-ready machine learning systems.",
            "general": "I'm a DevSecOps and AI/ML engineer focused on building practical, production-ready solutions that deliver measurable business value.",
        }

        base_response = context_responses.get(
            request.context_type, context_responses["general"]
        )

        # Use GPT to enhance the response
        enhanced_prompt = f"""
        Based on this query: "{request.query}"
        And this context: "{base_response}"
        
        Provide a detailed, professional response about Jimmie Coleman's experience and expertise.
        Include specific examples and technologies where relevant.
        Keep the response focused and informative for interview/recruitment purposes.
        """

        response = openai.chat.completions.create(
            model=GPT_MODEL,
            messages=[
                {
                    "role": "system",
                    "content": "You are providing detailed information about Jimmie Coleman's technical expertise and projects.",
                },
                {"role": "user", "content": enhanced_prompt},
            ],
            max_tokens=400,
            temperature=0.7,
        )

        return QueryResponse(
            answer=response.choices[0].message.content,
            sources=[
                {
                    "type": request.context_type,
                    "title": f"Jimmie's {request.context_type.title()} Experience",
                    "relevance": 0.95,
                }
            ],
            context_used=request.context_type,
            timestamp=datetime.now(),
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Query failed: {str(e)}")


@app.get("/notebooks")
async def list_notebooks():
    """List available Jupyter notebooks"""
    return {
        "notebooks": [
            {
                "name": "rag_pipeline_main.ipynb",
                "description": "Main RAG pipeline implementation",
                "url": "http://localhost:8888/lab/tree/rag_pipeline_main.ipynb",
            },
            {
                "name": "knowledge_ingestion.ipynb",
                "description": "Knowledge base ingestion and processing",
                "url": "http://localhost:8888/lab/tree/knowledge_ingestion.ipynb",
            },
            {
                "name": "embedding_analysis.ipynb",
                "description": "Vector embedding analysis and optimization",
                "url": "http://localhost:8888/lab/tree/embedding_analysis.ipynb",
            },
        ],
        "jupyter_url": "http://localhost:8888/lab?token=portfolio-rag-2025",
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=8000)
