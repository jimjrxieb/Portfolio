#!/usr/bin/env bash
set -euo pipefail

# Comprehensive API verification script
API_BASE="${API_BASE:-http://localhost:8000}"
TIMEOUT="${TIMEOUT:-10}"

echo "🔍 Clean API Verification"
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

# 1. Debug State Check
echo "✅ 1. Debug State & Configuration"
echo -n "  API State: "
if DEBUG_RESULT=$(call_api "/api/debug/state"); then
    echo "✓ Connected"
    echo "    Provider: $(echo "$DEBUG_RESULT" | jq -r '.provider')"
    echo "    Model: $(echo "$DEBUG_RESULT" | jq -r '.model')"
    echo "    Namespace: $(echo "$DEBUG_RESULT" | jq -r '.namespace')"
    echo "    Chroma OK: $(echo "$DEBUG_RESULT" | jq -r '.chroma_ok')"
    echo "    LLM OK: $(echo "$DEBUG_RESULT" | jq -r '.llm_ok')"
    echo "    Collections: $(echo "$DEBUG_RESULT" | jq -r '.collections | length') found"
else
    echo "❌ Failed to connect to debug endpoint"
fi

# 2. Health Checks
echo
echo "✅ 2. Health Endpoints"
echo -n "  Root health: "
if call_api "/health" >/dev/null 2>&1; then
    echo "✓ OK"
else
    echo "❌ Failed"
fi

echo -n "  LLM health: "
if LLM_RESULT=$(call_api "/api/health/llm"); then
    echo "✓ $(echo "$LLM_RESULT" | jq -r '.provider + "/" + .model')"
    LLM_OK=$(echo "$LLM_RESULT" | jq -r '.ok')
    echo "    Status: $LLM_OK"
else
    echo "❌ Failed"
fi

echo -n "  RAG health: "
if RAG_RESULT=$(call_api "/api/health/rag"); then
    echo "✓ Namespace: $(echo "$RAG_RESULT" | jq -r '.namespace')"
    echo "    Status: $(echo "$RAG_RESULT" | jq -r '.ok') ($(echo "$RAG_RESULT" | jq -r '.hits // 0') hits)"
else
    echo "❌ Failed"
fi

# 3. RAG Document Count
echo
echo "✅ 3. RAG Collection Status"
echo -n "  Document count: "
if COUNT_RESULT=$(call_api "/api/actions/rag/count"); then
    COUNT=$(echo "$COUNT_RESULT" | jq -r '.count')
    NAMESPACE=$(echo "$COUNT_RESULT" | jq -r '.namespace')
    echo "✓ $COUNT documents in '$NAMESPACE'"

    if [ "$COUNT" -eq 0 ]; then
        echo "    ⚠️  No documents found - RAG may need seeding"
    fi
else
    echo "❌ Failed to get document count"
fi

# 4. Chat Functionality Test
echo
echo "✅ 4. Chat Integration Test"
CHAT_PAYLOAD='{"message":"What is your name?","namespace":"portfolio","k":3}'
echo -n "  Chat response: "
if CHAT_RESULT=$(call_api "/api/chat" "POST" "$CHAT_PAYLOAD"); then
    if echo "$CHAT_RESULT" | jq -e '.answer' >/dev/null 2>&1; then
        echo "✓ Got answer"
        echo "    Model: $(echo "$CHAT_RESULT" | jq -r '.model // "unknown"')"
        echo "    Citations: $(echo "$CHAT_RESULT" | jq -r '.citations | length // 0')"
        ANSWER_PREVIEW=$(echo "$CHAT_RESULT" | jq -r '.answer' | head -c 50)
        echo "    Preview: ${ANSWER_PREVIEW}..."
    else
        echo "❌ No answer field in response"
        echo "    Response: $(echo "$CHAT_RESULT" | head -c 200)"
    fi
else
    echo "❌ Chat request failed"
fi

# 5. Avatar Endpoints
echo
echo "✅ 5. Avatar System"
echo -n "  Avatar fallback: "
if AVATAR_RESULT=$(call_api "/api/actions/avatar/talk" "POST" '{"text":"test"}'); then
    if echo "$AVATAR_RESULT" | jq -e '.url' >/dev/null 2>&1; then
        AUDIO_URL=$(echo "$AVATAR_RESULT" | jq -r '.url')
        echo "✓ Returns audio URL: $AUDIO_URL"
    else
        echo "⚠️  Unexpected response format"
    fi
else
    echo "⚠️  Avatar endpoint may require different payload"
fi

echo -n "  Default intro asset: "
if call_api "/api/assets/default-intro" >/dev/null 2>&1; then
    echo "✓ Available"
else
    echo "⚠️  Default intro not found"
fi

# 6. Security Checks
echo
echo "✅ 6. Security Verification"
echo -n "  CORS headers: "
if CORS_CHECK=$(curl -sS --max-time "$TIMEOUT" -H "Origin: https://malicious.com" "$API_BASE/health" -D-); then
    if echo "$CORS_CHECK" | grep -q "Access-Control-Allow-Origin"; then
        ALLOWED_ORIGIN=$(echo "$CORS_CHECK" | grep "Access-Control-Allow-Origin" | cut -d' ' -f2- | tr -d '\r')
        if [ "$ALLOWED_ORIGIN" = "*" ]; then
            echo "⚠️  CORS allows all origins (*)"
        else
            echo "✓ CORS restricted to: $ALLOWED_ORIGIN"
        fi
    else
        echo "✓ No permissive CORS"
    fi
else
    echo "❌ Could not check CORS"
fi

# Summary
echo
echo "🎯 Verification Summary"
echo "📊 Endpoints tested:"
echo "   - ✓ Debug state & configuration"
echo "   - ✓ Health checks (root, LLM, RAG)"
echo "   - ✓ RAG document count"
echo "   - ✓ Chat integration"
echo "   - ✓ Avatar fallback system"
echo "   - ✓ Security headers"
echo
echo "🔧 If any checks failed:"
echo "   - Debug: Check LLM_PROVIDER, LLM_MODEL, LLM_API_BASE"
echo "   - RAG: Check CHROMA_URL and run RAG ingestion"
echo "   - Chat: Verify API routes and model connectivity"
echo "   - Avatar: Check for default assets and fallback handling"
echo "   - CORS: Verify allowed origins for UI domain"
echo
echo "📖 Full troubleshooting: see docs/RUNBOOK.md"

# Exit code based on critical checks
if [ "${LLM_OK:-false}" = "true" ] && [ "${COUNT:-0}" -gt 0 ]; then
    echo "✅ Core functionality verified - API ready for UI integration"
    exit 0
else
    echo "⚠️  Some core functionality may need attention"
    exit 1
fi
