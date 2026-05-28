# Archived API Routes

These routes are not mounted by `api/main.py` and are not part of the current
production API surface.

They are kept here as implementation history only:

| File | Former purpose | Reason archived |
|---|---|---|
| `debug.py` | Debug state and connectivity checks. | Debug endpoints should not be exposed in production. |
| `rag.py` | RAG versioning and ingest management endpoints. | RAG management moved to pipeline/operator workflows instead of public API routes. |
| `uploads.py` | Public image upload endpoint. | Uploads are not used by the current frontend and increase attack surface. |

Do not mount these routes without a fresh COMPLY/BUILD/BREAK review.
