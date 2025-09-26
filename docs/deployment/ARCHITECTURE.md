# Portfolio Platform Architecture

## Overview

The Portfolio platform is a simplified, production-ready AI chatbot application designed for deployment via ArgoCD. The architecture follows cloud-native principles with containerized services and enterprise-grade security.

## Simplified Architecture (Option A)

### **Deployment Components**

```
┌─────────────────────────────────────────────────────────────┐
│                 Portfolio Platform                          │
├─────────────────────────────────────────────────────────────┤
│  Frontend (UI)    │  Backend (API+Jade)  │  Database        │
│  • React App      │  • FastAPI Server    │  • ChromaDB      │
│  • Northstar Chat │  • Jade-Brain AI     │  • Vector Store  │
│  • TypeScript     │  • RAG Engine        │  • 391+ Docs    │
│  • Port: 3000     │  • Port: 8000        │  • Port: 8001    │
└─────────────────────────────────────────────────────────────┘
```

### **Service Breakdown**

#### **1. API Service** (api/)
- **Base**: FastAPI + Jade-Brain integrated
- **Components**:
  - `main.py` - FastAPI application
  - `engines/` - RAG and AI processing engines
  - `jade_config/` - AI model configuration
  - `personality/` - Jade AI personality definitions
  - `routes/` - API endpoints
- **Image**: `ghcr.io/jimjrxieb/portfolio-api:latest`
- **Features**:
  - AI chat responses via Jade-Brain
  - RAG-powered knowledge retrieval
  - File upload handling
  - Health monitoring

#### **2. UI Service** (ui/)
- **Base**: React with TypeScript
- **Features**:
  - Northstar-styled chatbox interface
  - Real-time AI conversation
  - Responsive design
  - Avatar integration
- **Image**: `ghcr.io/jimjrxieb/portfolio-ui:latest`
- **Build**: Vite + Tailwind CSS

#### **3. ChromaDB Service**
- **Base**: Official ChromaDB image
- **Purpose**: Vector database for document embeddings
- **Data**: 391+ embedded documents
- **Persistence**: Volume-mounted storage
- **Image**: `chromadb/chroma:latest`

### **Development Tools (Local Only)**

#### **RAG Pipeline** (rag-pipeline/)
- **Purpose**: Data ingestion and embedding generation
- **Scope**: ROG Strix development machine only
- **Function**: Processes documents → stores in ChromaDB
- **Not Deployed**: Stays local for content management

## Deployment Strategy

### **ArgoCD Configuration**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: portfolio
  annotations:
    argocd.argoproj.io/refresh: "2025-09-26-simplified-architecture"
spec:
  source:
    repoURL: https://github.com/jimjrxieb/Portfolio.git
    path: helm/portfolio
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: portfolio
```

### **Container Registry**
- **Primary**: GitHub Container Registry (GHCR)
- **Images**:
  - `ghcr.io/jimjrxieb/portfolio-api:latest`
  - `ghcr.io/jimjrxieb/portfolio-ui:latest`
- **Security**: Vulnerability scanning with Trivy

### **Data Flow**

```
[ROG Strix Development]
RAG Pipeline → Embeds Data → ChromaDB Volume

[Deployed Platform]
User → UI → API+Jade → ChromaDB → AI Response → UI → User
```

## Infrastructure Components

### **Kubernetes Resources**

#### **Deployments**
- `portfolio-api`: FastAPI + Jade-Brain service
- `portfolio-ui`: React frontend service
- `chromadb`: Vector database service

#### **Services**
- `portfolio-api-service`: ClusterIP for internal communication
- `portfolio-ui-service`: LoadBalancer for external access
- `chromadb-service`: ClusterIP for database access

#### **Persistent Volumes**
- `chroma-data-pvc`: ChromaDB data persistence
- `upload-data-pvc`: File upload storage

#### **ConfigMaps**
- `portfolio-config`: Environment variables
- `jade-personality`: AI personality configuration

#### **Secrets**
- `portfolio-secrets`: API keys and sensitive configuration

### **Networking**

#### **Network Policies**
- Default deny-all ingress/egress
- Allow DNS resolution
- Allow inter-service communication
- Restrict external access

#### **Ingress**
- External access to UI service
- SSL/TLS termination
- Path-based routing

## Security Architecture

### **Container Security**
- **Non-root users**: All containers run as UID 1000
- **Resource limits**: CPU and memory constraints
- **Security contexts**: Read-only filesystems where possible
- **Image scanning**: Trivy vulnerability detection

### **Network Security**
- **Network policies**: Microsegmentation
- **Service mesh**: Optional Istio integration
- **TLS encryption**: Inter-service communication

### **Policy Enforcement**
- **OPA/Conftest**: Infrastructure policy validation
- **RBAC**: Kubernetes role-based access control
- **Pod Security**: Security contexts and standards

## Configuration Management

### **Environment Variables**

#### API Service
```yaml
CHROMA_URL: http://chromadb:8000
GPT_MODEL: gpt-4o-mini
OPENAI_API_KEY: ${OPENAI_API_KEY}
PYTHONPATH: /app
```

#### UI Service
```yaml
VITE_API_URL: http://localhost:8000
VITE_CHROMA_URL: http://localhost:8001
```

### **Volume Mounts**
```yaml
api:
  - /data/chroma: ChromaDB data access
  - /data/uploads: File upload storage

chromadb:
  - /chroma/data: Persistent vector storage
```

## Monitoring & Observability

### **Health Checks**
```yaml
api:
  httpGet:
    path: /health
    port: 8000

ui:
  httpGet:
    path: /
    port: 80

chromadb:
  httpGet:
    path: /health
    port: 8000
```

### **Logging**
- **Structured logs**: JSON format
- **Log aggregation**: Kubernetes logs
- **Error tracking**: Application-level error handling

### **Metrics**
- **Application metrics**: Custom FastAPI metrics
- **Infrastructure metrics**: Kubernetes resource usage
- **Performance monitoring**: Response time tracking

## Development Workflow

### **Local Development**
```bash
# Full platform
docker-compose up --build -d

# Individual services
cd api && uvicorn main:app --reload
cd ui && npm run dev
```

### **Data Management**
```bash
# Update knowledge base (ROG Strix only)
docker-compose --profile dev-tools up rag-pipeline
```

### **Deployment**
```bash
# Build and push images
git push origin main  # Triggers CI/CD

# ArgoCD sync
kubectl apply -f argocd/portfolio-application.yaml
```

## Scaling Considerations

### **Horizontal Scaling**
- **API**: Stateless, can scale horizontally
- **UI**: Static content, CDN-friendly
- **ChromaDB**: Single instance (vector DB)

### **Vertical Scaling**
- **API**: Memory for model inference
- **ChromaDB**: Storage for vector data
- **UI**: Minimal resource requirements

### **Performance Optimization**
- **Caching**: API response caching
- **CDN**: Static asset delivery
- **Connection pooling**: Database connections

## Disaster Recovery

### **Backup Strategy**
- **ChromaDB data**: Volume snapshots
- **Configuration**: GitOps repository
- **Secrets**: External secret management

### **Recovery Procedures**
- **Data restore**: Volume restoration
- **Service recovery**: ArgoCD re-deployment
- **Configuration drift**: GitOps reconciliation

---

**Last Updated**: September 26, 2025
**Version**: 1.0 (Simplified Architecture)
**Deployment Target**: Old laptop via ArgoCD