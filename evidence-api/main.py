"""
Evidence API — collects GRC audit evidence from the cluster.

Runs directly on the target host (has native kubectl access).
Called by n8n HTTP Request nodes to gather evidence per control family.

Auth: X-API-Key header (set API_KEY env var, default: changeme)

Endpoints:
  GET  /health
  POST /evidence/rbac       → AC-2, AC-3, AC-6
  POST /evidence/pods       → CM-6, CM-7, SC-28
  POST /evidence/cluster    → kube-bench + kubescape (CM-6, SC-7, SI-2)
  POST /evidence/network    → SC-7, AC-4
  POST /evidence/all        → runs all collectors, returns full bundle
"""

import os
from datetime import datetime, timezone
from fastapi import FastAPI, HTTPException, Security
from fastapi.security.api_key import APIKeyHeader

API_KEY = os.getenv("API_KEY", "changeme")
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)

app = FastAPI(
    title="Evidence API",
    description="GRC audit evidence collector for NIST 800-53 assessments",
    version="1.0.0",
)


def require_key(key: str = Security(api_key_header)):
    if key != API_KEY:
        raise HTTPException(status_code=403, detail="Invalid or missing API key")
    return key


@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "evidence-api",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.post("/evidence/rbac")
def evidence_rbac(key: str = Security(require_key)):
    from collectors.rbac import collect
    try:
        return collect()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/evidence/pods")
def evidence_pods(key: str = Security(require_key)):
    from collectors.pods import collect
    try:
        return collect()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/evidence/cluster")
def evidence_cluster(key: str = Security(require_key)):
    from collectors.cluster import collect
    try:
        return collect()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/evidence/network")
def evidence_network(key: str = Security(require_key)):
    from collectors.network import collect
    try:
        return collect()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/evidence/all")
def evidence_all(key: str = Security(require_key)):
    from collectors.rbac import collect as rbac
    from collectors.pods import collect as pods
    from collectors.cluster import collect as cluster
    from collectors.network import collect as network

    results = {}
    errors = {}

    for name, fn in [("rbac", rbac), ("pods", pods), ("cluster", cluster), ("network", network)]:
        try:
            results[name] = fn()
        except Exception as e:
            errors[name] = str(e)

    return {
        "collected_at": datetime.now(timezone.utc).isoformat(),
        "collectors_run": list(results.keys()),
        "collectors_failed": errors,
        "evidence": results,
    }
