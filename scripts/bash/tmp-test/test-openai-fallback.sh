#!/usr/bin/env bash
set -euo pipefail

# GPT-4o mini fallback test - isolate connectivity issues
API_BASE="${API_BASE:-http://localhost:8000}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"

if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ OPENAI_API_KEY environment variable is required"
    echo "   Set it with: export OPENAI_API_KEY=sk-proj-..."
    exit 1
fi

echo "🔄 Testing GPT-4o mini fallback"
echo "API Base: $API_BASE"
echo "Using OpenAI API Key: ${OPENAI_API_KEY:0:20}..."
echo

# Test 1: Set API to use OpenAI GPT-4o mini
echo "✅ 1. Switching API to GPT-4o mini"
kubectl -n portfolio set env deploy/portfolio-api \
    LLM_PROVIDER=openai \
    LLM_API_BASE=https://api.openai.com \
    LLM_MODEL=gpt-4o-mini \
    "LLM_API_KEY=$OPENAI_API_KEY"

echo "♻️ Restarting API deployment"
kubectl -n portfolio rollout restart deploy/portfolio-api
kubectl -n portfolio rollout status deploy/portfolio-api --timeout=180s

echo "⏳ Waiting 10s for API to stabilize..."
sleep 10

# Test 2: Verify OpenAI connection
echo
echo "✅ 2. Testing OpenAI connectivity"
if DEBUG_RESULT=$(curl -sS --max-time 15 "$API_BASE/api/debug/state"); then
    echo "Debug response:"
    echo "$DEBUG_RESULT" | jq '{provider, model, llm_ok, chroma_ok}'
    
    LLM_OK=$(echo "$DEBUG_RESULT" | jq -r '.llm_ok')
    if [ "$LLM_OK" = "true" ]; then
        echo "✅ OpenAI LLM connection successful"
    else
        echo "❌ OpenAI LLM connection failed"
        echo "Error: $(echo "$DEBUG_RESULT" | jq -r '.llm_error // "Unknown"')"
    fi
else
    echo "❌ Failed to reach debug endpoint"
fi

# Test 3: Direct chat test with GPT-4o mini
echo
echo "✅ 3. Testing chat with GPT-4o mini"
CHAT_PAYLOAD='{"message":"Hello! Can you tell me about Jade at ZRS Management?","namespace":"portfolio","k":3}'

if CHAT_RESULT=$(curl -sS --max-time 20 -X POST "$API_BASE/api/chat" \
    -H 'Content-Type: application/json' \
    -d "$CHAT_PAYLOAD"); then
    
    if echo "$CHAT_RESULT" | jq -e '.answer' >/dev/null 2>&1; then
        echo "✅ Chat successful with GPT-4o mini!"
        echo "Model: $(echo "$CHAT_RESULT" | jq -r '.model')"
        echo "Citations: $(echo "$CHAT_RESULT" | jq -r '.citations | length')"
        echo "Answer preview: $(echo "$CHAT_RESULT" | jq -r '.answer' | head -c 100)..."
        
        echo
        echo "🎯 DIAGNOSIS: Your API routes and UI integration are working!"
        echo "   The issue was with Ollama/local connectivity, not your code."
        echo "   You can now:"
        echo "   1. Keep using GPT-4o mini as fallback (fast, cheap: \$0.15/1M input tokens)"
        echo "   2. Or fix your Ollama/Chroma setup and switch back"
        
    else
        echo "❌ Chat failed - response format issue"
        echo "Response: $(echo "$CHAT_RESULT" | jq . || echo "$CHAT_RESULT")"
        
        echo
        echo "🎯 DIAGNOSIS: Issue is in your API routes or request format"
        echo "   Not a connectivity problem - check /api/chat endpoint implementation"
    fi
else
    echo "❌ Chat request failed completely"
    
    echo
    echo "🎯 DIAGNOSIS: Issue is with CORS, routing, or UI → API communication"
    echo "   Check VITE_API_BASE in UI .env and CORS_ORIGINS in API"
fi

# Test 4: Test UI integration (if running)
echo
echo "✅ 4. UI Integration Test"
echo "📖 Open your UI at: https://your-ui-domain"
echo "   - Model banner should show: 'Model: gpt-4o-mini'"
echo "   - Chat should work without 'chat failed' errors"
echo "   - Responses should be faster and more consistent"

echo
echo "💡 GPT-4o mini Benefits:"
echo "   - \$0.15/1M input tokens (\$0.60/1M output)"
echo "   - 128k context window, up to 16k output"
echo "   - Fast, reliable, good for Q&A and RAG"
echo "   - Perfect fallback while debugging local setup"

echo
echo "🔄 To revert to Ollama:"
echo "kubectl -n portfolio set env deploy/portfolio-api \\"
echo "  LLM_PROVIDER=ollama \\"
echo "  LLM_API_BASE=http://ollama:11434 \\"
echo "  LLM_MODEL=phi3:latest \\"
echo "  LLM_API_KEY="