#!/bin/bash

echo "🚀 Testing Portfolio MVP Setup..."

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Build and start services
echo "📦 Building and starting services..."
docker-compose up --build -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Check API health
echo "🔍 Checking API health..."
if curl -f http://localhost:8000/health >/dev/null 2>&1; then
    echo "✅ API is healthy"
else
    echo "❌ API health check failed"
    docker-compose logs api
    exit 1
fi

# Check UI
echo "🔍 Checking UI..."
if curl -f http://localhost:5173 >/dev/null 2>&1; then
    echo "✅ UI is responding"
else
    echo "❌ UI health check failed"
    docker-compose logs ui
    exit 1
fi

# Ingest data
echo "📚 Ingesting persona and talktrack data..."
docker-compose exec -T api python preprocess.py

echo "✅ Setup complete!"
echo "🌐 Open http://localhost:5173 in your browser"
echo "❓ Try asking: 'Tell me about yourself'"
