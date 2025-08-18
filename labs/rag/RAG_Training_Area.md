# RAG Training Area - Jupyter Notebook Cells

Copy/paste these **Jupyter cells** if you open a notebook (local or Colab). They just call your API; no secrets:

## Cell 1: Setup

```python
API_BASE = "https://your-api.example.com"  # <- set this
```

## Cell 2: Ingest

```python
import requests, json
docs = [
  {"id": "zrs-1", "text": "ZRS Management is a property management company in Orlando, FL.", "source": "001_zrs_overview.md"},
  {"id": "sla-1", "text": "Work orders must be acknowledged within 1 business day.", "source": "002_sla.md"},
  {"id": "afterlife-1", "text": "LinkOps Afterlife is an open-source avatar memorial project.", "source": "003_afterlife_overview.md"}
]
r = requests.post(f"{API_BASE}/ingest", json=docs)
r.raise_for_status()
r.json()
```

## Cell 3: Ask

```python
q = "Who is ZRS and what is the SLA for work orders?"
r = requests.post(f"{API_BASE}/chat", json={"question": q, "k": 5})
r.raise_for_status()
r.text  # Returns streaming text
```

## Cell 4: Health Check

```python
# Check API health
health = requests.get(f"{API_BASE}/healthz").json()
engines = requests.get(f"{API_BASE}/engines").json()
print("Health:", health)
print("Engines:", engines)
```

## Cell 5: Test Different Questions

```python
questions = [
    "What is LinkOps Afterlife?",
    "What are the work order requirements?",
    "Tell me about ZRS Management"
]

for q in questions:
    print(f"\n❓ {q}")
    try:
        r = requests.post(f"{API_BASE}/chat", json={"question": q, "k": 3})
        r.raise_for_status()
        result = r.text
        print(f"Answer: {result}")
    except Exception as e:
        print(f"Error: {e}")
```

## Usage Notes

- Replace `API_BASE` with your actual API endpoint
- The `/ingest` endpoint expects documents with `id`, `text`, and `source` fields
- The `/chat` endpoint expects `question` and optional `k` (number of results)
- The `/chat` endpoint returns streaming text (not JSON)
- No API keys needed for these endpoints (they use server-side configuration)
