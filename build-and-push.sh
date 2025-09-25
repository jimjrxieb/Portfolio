#!/bin/bash
set -e

# Portfolio Container Build and Push Script
# Builds all services and pushes to GitHub Container Registry

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🐳 Portfolio Container Build and Push${NC}"
echo -e "${GREEN}====================================${NC}"

# Configuration
REGISTRY="ghcr.io"
USERNAME="jimjrxieb"
PROJECT="portfolio"
TAG="${1:-latest}"

# Services to build
SERVICES=("ui" "api" "chromadb" "avatar-creation" "rag-pipeline")

echo -e "${BLUE}📋 Configuration:${NC}"
echo -e "  Registry: ${REGISTRY}"
echo -e "  Username: ${USERNAME}"
echo -e "  Project: ${PROJECT}"
echo -e "  Tag: ${TAG}"
echo -e "  Services: ${SERVICES[*]}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running!${NC}"
    exit 1
fi

# Check if logged in to GitHub Container Registry
if ! docker info 2>/dev/null | grep -q "ghcr.io"; then
    echo -e "${YELLOW}🔐 Please login to GitHub Container Registry:${NC}"
    echo -e "  docker login ghcr.io -u ${USERNAME}"
    echo ""
    read -p "Press Enter to continue once logged in..."
fi

echo -e "${BLUE}🏗️  Building containers...${NC}"

# Build all services
for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}Building ${service}...${NC}"

    if [ -d "./${service}" ] && [ -f "./${service}/Dockerfile" ]; then
        # Build the service
        docker build -t "${REGISTRY}/${USERNAME}/${PROJECT}-${service}:${TAG}" "./${service}"

        # Also tag as latest if not already latest
        if [ "${TAG}" != "latest" ]; then
            docker tag "${REGISTRY}/${USERNAME}/${PROJECT}-${service}:${TAG}" \
                      "${REGISTRY}/${USERNAME}/${PROJECT}-${service}:latest"
        fi

        echo -e "${GREEN}✅ Built ${service}${NC}"
    else
        echo -e "${RED}❌ Missing Dockerfile for ${service}${NC}"
        exit 1
    fi
done

echo ""
echo -e "${BLUE}📤 Pushing containers...${NC}"

# Push all services
for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}Pushing ${service}:${TAG}...${NC}"

    docker push "${REGISTRY}/${USERNAME}/${PROJECT}-${service}:${TAG}"

    # Push latest tag if different
    if [ "${TAG}" != "latest" ]; then
        echo -e "${YELLOW}Pushing ${service}:latest...${NC}"
        docker push "${REGISTRY}/${USERNAME}/${PROJECT}-${service}:latest"
    fi

    echo -e "${GREEN}✅ Pushed ${service}${NC}"
done

echo ""
echo -e "${GREEN}🎉 All containers built and pushed successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Container Images:${NC}"
for service in "${SERVICES[@]}"; do
    echo -e "  ${REGISTRY}/${USERNAME}/${PROJECT}-${service}:${TAG}"
done

echo ""
echo -e "${YELLOW}🚀 Next Steps:${NC}"
echo -e "  1. Update Helm values with new image tags (if not latest)"
echo -e "  2. Commit and push Helm chart changes"
echo -e "  3. ArgoCD will automatically sync the deployment"
echo -e "  4. Monitor deployment: kubectl get pods -n portfolio"
echo ""
echo -e "${GREEN}🔗 Useful Commands:${NC}"
echo -e "  # Deploy via Helm:"
echo -e "  helm install portfolio ./helm/portfolio -n portfolio"
echo ""
echo -e "  # Deploy via ArgoCD:"
echo -e "  kubectl apply -f argocd/portfolio-application.yaml"
echo ""
echo -e "  # Check deployment:"
echo -e "  kubectl get all -n portfolio"
echo -e "  kubectl get application portfolio -n argocd"