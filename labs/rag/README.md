# RAG Training Area

This directory contains tools and scripts for testing and training your RAG (Retrieval-Augmented Generation) system. This is **NOT** for model fine-tuning - it's for ingesting documents into your knowledge base and testing retrieval.

## Quick Start

### 1. Set your API endpoint
```bash
export API_BASE="https://your-api.example.com"
# or for local development:
export API_BASE="http://localhost:8000"
```

### 2. Run the smoke test
```bash
./rag_smoketest.sh
```

### 3. Run the full lab
```bash
python rag_lab.py
```

## What's Included

### Sample Data
- `../data/rag/jimmie/` - Sample markdown files for testing
  - `001_zrs_overview.md` - ZRS Management company info
  - `002_sla.md` - Service Level Agreement details  
  - `003_afterlife_overview.md` - LinkOps Afterlife project info

### Scripts
- `rag_lab.py` - Full RAG testing script (ingest + query)
- `rag_smoketest.sh` - Quick API health and functionality test
- `RAG_Training_Area.md` - Jupyter notebook cells for copy/paste

## API Endpoints Used

Your existing API already has these endpoints:
- `POST /ingest` - Ingest documents into ChromaDB
- `POST /chat` - Ask questions (returns streaming text)
- `GET /healthz` - Health check
- `GET /engines` - Show available engines

## Jupyter Notebook Usage

Copy/paste cells from `RAG_Training_Area.md` into your notebook:

1. **Setup** - Set your API_BASE
2. **Ingest** - Upload sample documents
3. **Ask** - Test question answering
4. **Health Check** - Verify API status
5. **Test Questions** - Try different queries

## Troubleshooting

### If scripts fail:
1. Check API_BASE is set correctly
2. Verify your API is running (`curl $API_BASE/healthz`)
3. Check CORS settings if calling from browser
4. Ensure ChromaDB is accessible

### If chat returns errors:
1. Verify documents were ingested successfully
2. Check LLM configuration in your API
3. Review API logs for detailed error messages

## Security Notes

- No API keys in scripts (uses server-side config)
- Input validation handled by your API
- CORS should be restricted to your UI domain in production
- Rate limiting recommended for `/ingest` endpoint

## Next Steps

1. Replace sample data with your actual documents
2. Customize chunking strategy in `rag_lab.py`
3. Add more sophisticated query testing
4. Integrate with your CI/CD pipeline for automated testing
