#!/usr/bin/env bash
set -euo pipefail

# Direct GPT-4o mini test (bypasses your API entirely)
OPENAI_API_KEY="${OPENAI_API_KEY:-}"

if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ OPENAI_API_KEY environment variable is required"
    echo "   Get one from: https://platform.openai.com/api-keys"
    echo "   Set it with: export OPENAI_API_KEY=sk-proj-..."
    exit 1
fi

echo "🧪 Direct GPT-4o mini Test"
echo "Testing OpenAI API connectivity and pricing"
echo "Key: ${OPENAI_API_KEY:0:20}..."
echo

# Test GPT-4o mini directly
echo "✅ Calling GPT-4o mini directly..."

PAYLOAD='{
  "model": "gpt-4o-mini",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant for a portfolio website. Be concise."},
    {"role": "user", "content": "Hello! Tell me about Jade at ZRS Management - what does it do for property management?"}
  ],
  "max_tokens": 150,
  "temperature": 0.7
}'

if RESPONSE=$(curl -sS --max-time 15 \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$PAYLOAD" \
    "https://api.openai.com/v1/chat/completions"); then
    
    if echo "$RESPONSE" | jq -e '.choices[0].message.content' >/dev/null 2>&1; then
        echo "✅ GPT-4o mini responding successfully!"
        echo
        echo "Model: $(echo "$RESPONSE" | jq -r '.model')"
        echo "Usage: $(echo "$RESPONSE" | jq '.usage')"
        echo
        echo "Response:"
        echo "$(echo "$RESPONSE" | jq -r '.choices[0].message.content')"
        
        # Calculate rough cost
        INPUT_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.prompt_tokens')
        OUTPUT_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.completion_tokens')
        INPUT_COST=$(echo "scale=6; $INPUT_TOKENS * 0.15 / 1000000" | bc -l)
        OUTPUT_COST=$(echo "scale=6; $OUTPUT_TOKENS * 0.60 / 1000000" | bc -l)
        TOTAL_COST=$(echo "scale=6; $INPUT_COST + $OUTPUT_COST" | bc -l)
        
        echo
        echo "💰 Cost Analysis:"
        echo "   Input: $INPUT_TOKENS tokens × \$0.15/1M = \$$INPUT_COST"
        echo "   Output: $OUTPUT_TOKENS tokens × \$0.60/1M = \$$OUTPUT_COST"
        echo "   Total: \$$TOTAL_COST (very cheap!)"
        
        echo
        echo "🎯 DIAGNOSIS: OpenAI connectivity is perfect!"
        echo "   If your API still fails with these settings:"
        echo "   - LLM_PROVIDER=openai"
        echo "   - LLM_API_BASE=https://api.openai.com"  
        echo "   - LLM_MODEL=gpt-4o-mini"
        echo "   - LLM_API_KEY=$OPENAI_API_KEY"
        echo
        echo "   Then the issue is in your API route implementation, not connectivity."
        
    else
        echo "❌ GPT-4o mini error response:"
        echo "$RESPONSE" | jq .
        
        if echo "$RESPONSE" | jq -e '.error.code' >/dev/null 2>&1; then
            ERROR_CODE=$(echo "$RESPONSE" | jq -r '.error.code')
            ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message')
            echo
            echo "🎯 DIAGNOSIS: OpenAI API error"
            echo "   Code: $ERROR_CODE"
            echo "   Message: $ERROR_MSG"
            
            if [ "$ERROR_CODE" = "invalid_api_key" ]; then
                echo "   → Check your API key at https://platform.openai.com/api-keys"
            elif [ "$ERROR_CODE" = "insufficient_quota" ]; then
                echo "   → Add billing info at https://platform.openai.com/account/billing"
            fi
        fi
    fi
else
    echo "❌ Failed to connect to OpenAI API"
    echo "Check your internet connection and API key"
fi

echo
echo "💡 GPT-4o mini Benefits for Your Portfolio:"
echo "   ✓ \$0.15/1M input tokens (\$0.60/1M output) - very cost effective"
echo "   ✓ 128k context window - handles long conversations"
echo "   ✓ Fast response times - good user experience"  
echo "   ✓ Reliable uptime - perfect fallback for interviews"
echo "   ✓ Good at Q&A and RAG - ideal for portfolio chat"
echo
echo "🔄 To use as fallback in your API, set these env vars:"
echo "   LLM_PROVIDER=openai"
echo "   LLM_API_BASE=https://api.openai.com"
echo "   LLM_MODEL=gpt-4o-mini" 
echo "   LLM_API_KEY=$OPENAI_API_KEY"