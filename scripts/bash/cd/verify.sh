#!/usr/bin/env bash
set -euo pipefail

# Quick verification script for Portfolio deployment
API_BASE="${API_BASE:-http://localhost:8000}"
TIMEOUT="${TIMEOUT:-10}"

echo "🔍 Portfolio System Verification"
echo "API Base: $API_BASE"
echo "Timeout: ${TIMEOUT}s"
echo

# Helper function for API calls
call_api() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"

    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        curl -sS --max-time "$TIMEOUT" -X POST \
            -H 'Content-Type: application/json' \
            -d "$data" \
            "$API_BASE$endpoint"
    else
        curl -sS --max-time "$TIMEOUT" "$API_BASE$endpoint"
    fi
}

# 1. Model + RAG health
echo "✅ 1. Model + RAG Health Checks"
echo -n "  LLM Health: "
if LLM_RESULT=$(call_api "/api/health/llm"); then
    echo "✓ $(echo "$LLM_RESULT" | jq -r '.provider + "/" + .model')"
    echo "    Status: $(echo "$LLM_RESULT" | jq -r '.ok')"
else
    echo "❌ Failed"
fi

echo -n "  RAG Health: "
if RAG_RESULT=$(call_api "/api/health/rag"); then
    echo "✓ Namespace: $(echo "$RAG_RESULT" | jq -r '.namespace')"
    echo "    Status: $(echo "$RAG_RESULT" | jq -r '.ok') ($(echo "$RAG_RESULT" | jq -r '.hits // 0') hits)"
else
    echo "❌ Failed"
fi

# 2. Basic API endpoints
echo
echo "✅ 2. Core API Endpoints"
echo -n "  Root health: "
if call_api "/health" >/dev/null 2>&1; then
    echo "✓ OK"
else
    echo "❌ Failed"
fi

echo -n "  Asset serving: "
if call_api "/api/assets/default-intro" >/dev/null 2>&1; then
    echo "✓ Default audio available"
else
    echo "⚠️  Default audio missing (expected for fallback)"
fi

# 3. Chat functionality
echo
echo "✅ 3. Chat Integration Test"
CHAT_PAYLOAD='{"message":"What is your name?","namespace":"portfolio","k":3}'
echo -n "  Chat response: "
if CHAT_RESULT=$(call_api "/api/chat" "POST" "$CHAT_PAYLOAD"); then
    if echo "$CHAT_RESULT" | jq -e '.answer' >/dev/null 2>&1; then
        echo "✓ Got answer"
        echo "    Model: $(echo "$CHAT_RESULT" | jq -r '.model // "unknown"')"
        echo "    Citations: $(echo "$CHAT_RESULT" | jq -r '.citations | length // 0')"
    else
        echo "❌ No answer field in response"
    fi
else
    echo "❌ Chat request failed"
fi

# 4. Avatar endpoints
echo
echo "✅ 4. Avatar System"
echo -n "  Avatar routes: "
if call_api "/api/actions/avatar/talk" "POST" '{"text":"test"}' >/dev/null 2>&1; then
    echo "✓ Avatar talk endpoint responding"
else
    echo "⚠️  Avatar endpoint may require valid payload"
fi

# 5. Security check
echo
echo "✅ 5. Security Verification"
echo -n "  CORS headers: "
if CORS_CHECK=$(curl -sS --max-time "$TIMEOUT" -H "Origin: https://malicious.com" "$API_BASE/health" -D-); then
    if echo "$CORS_CHECK" | grep -q "Access-Control-Allow-Origin"; then
        echo "⚠️  CORS headers present (check allowed origins)"
    else
        echo "✓ No permissive CORS"
    fi
else
    echo "❌ Could not check CORS"
fi

# Summary
echo
echo "🎯 Verification Complete"
echo "🔧 If any checks failed:"
echo "   - LLM: Check LLM_PROVIDER, LLM_MODEL, LLM_API_BASE settings"
echo "   - RAG: Check CHROMA_URL and run RAG ingestion"
echo "   - Chat: Verify API routes and model connectivity"
echo "   - Avatar: Check ELEVENLABS_API_KEY for full functionality"
echo
echo "📖 Full troubleshooting: see docs/RUNBOOK.md"
