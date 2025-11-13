#!/bin/bash
# Simple webhook listener for GitHub repository dispatch events
# Automatically deploys when GitHub Actions triggers deployment

WEBHOOK_PORT="${WEBHOOK_PORT:-8888}"
REPO_PATH="/home/jimjrxieb/shadow-link-industries/Portfolio"

echo "🎧 Starting GitHub webhook listener on port ${WEBHOOK_PORT}"
echo "   Listening for deployment events..."
echo "   Repository: ${REPO_PATH}"
echo ""

# Simple HTTP server that listens for POST requests
while true; do
    echo "Waiting for webhook..."

    # Listen for HTTP requests using netcat
    response=$(echo -e "HTTP/1.1 200 OK\r\nContent-Length: 21\r\n\r\nWebhook received! 📦" | nc -l -p ${WEBHOOK_PORT} -q 1)

    if [[ $response == *"deploy-to-local"* ]]; then
        echo "🚀 Deployment webhook received!"

        # Extract image tag from webhook payload (simple grep)
        IMAGE_TAG=$(echo "$response" | grep -o '"image_tag":"[^"]*"' | cut -d'"' -f4)

        if [ -n "$IMAGE_TAG" ]; then
            echo "📦 Deploying image tag: ${IMAGE_TAG}"

            # Change to repo directory and deploy
            cd "${REPO_PATH}"
            ./scripts/deploy-from-registry.sh "${IMAGE_TAG}"

            echo "✅ Deployment completed for ${IMAGE_TAG}"
        else
            echo "⚠️  No image tag found in webhook payload"

            # Deploy latest as fallback
            cd "${REPO_PATH}"
            ./scripts/deploy-from-registry.sh latest
        fi
    else
        echo "ℹ️  Non-deployment webhook received"
    fi

    echo ""
    sleep 2
done
