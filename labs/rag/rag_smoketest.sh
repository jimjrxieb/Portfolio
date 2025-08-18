#!/usr/bin/env bash
set -euo pipefail
: "${API_BASE:?Set API_BASE, e.g. export API_BASE=https://api.example.com}"

echo "🔎 Health"
curl -sS "$API_BASE/healthz" | jq
curl -sS "$API_BASE/api/health/llm" | jq
curl -sS "$API_BASE/api/health/rag" | jq

echo "🔍 Debug State"
curl -sS "$API_BASE/api/debug/state" | jq

echo "📥 Upsert sample chunks"
curl -sS -X POST "$API_BASE/ingest" -H 'Content-Type: application/json' -d '[
  {"id":"zrs-1","text":"ZRS Management is a property management company in Orlando, FL.","source":"001_zrs_overview.md"},
  {"id":"sla-1","text":"Work orders must be acknowledged within 1 business day.","source":"002_sla.md"},
  {"id":"afterlife-1","text":"LinkOps Afterlife is an open-source avatar memorial project.","source":"003_afterlife_overview.md"}
]' | jq

echo "❓ Ask"
curl -sS -X POST "$API_BASE/chat" -H 'Content-Type: application/json' -d '{
  "question":"Who is ZRS and what is the SLA for work orders?",
  "k":5
}' | jq
