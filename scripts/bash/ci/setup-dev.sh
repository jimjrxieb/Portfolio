#!/bin/bash
# Portfolio Development Setup Script

set -e

echo "🚀 Setting up Portfolio development environment..."

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Please run this script from the Portfolio root directory"
    exit 1
fi

# Install UI dependencies
echo "📦 Installing UI dependencies..."
cd ui
npm install
cd ..

# Install Python dependencies for API
echo "🐍 Installing Python dependencies..."
if command -v python3 &> /dev/null; then
    python3 -m pip install -r api/requirements.txt
else
    echo "⚠️  Python3 not found. Install manually: pip install -r api/requirements.txt"
fi

# Install Python dependencies for RAG pipeline
echo "🧠 Installing RAG pipeline dependencies..."
if command -v python3 &> /dev/null; then
    python3 -m pip install -r rag-pipeline/requirements.txt
else
    echo "⚠️  Python3 not found. Install manually: pip install -r rag-pipeline/requirements.txt"
fi

# Create necessary directories
echo "📁 Creating data directories..."
mkdir -p data/chroma
mkdir -p docs/configs
mkdir -p docs/general

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "⚙️  Copying .env.example to .env..."
    cp .env.example .env
    echo "📝 Please edit .env with your API keys"
else
    echo "✅ .env file already exists"
fi

echo ""
echo "✅ Setup complete! You can now:"
echo ""
echo "  🏗️  Build and start services:"
echo "     npm run dev"
echo ""
echo "  🎨 Start UI development:"
echo "     npm run dev:ui"
echo ""
echo "  🔍 Run linting:"
echo "     npm run lint"
echo ""
echo "  📊 RAG Pipeline:"
echo "     cd rag-pipeline && python3 rag_api.py"
echo ""
echo "  🧠 Jade-Brain API:"
echo "     cd Jade-Brain/api && python3 jade_api.py"
echo ""
echo "Happy coding! 🎉"
