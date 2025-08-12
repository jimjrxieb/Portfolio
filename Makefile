# Portfolio MVP - Local Kubernetes Deployment
.PHONY: help build-kind build-minikube deploy-kind deploy-minikube logs clean

help:
	@echo "Portfolio MVP - Local Kubernetes Commands"
	@echo ""
	@echo "KIND (recommended):"
	@echo "  make build-kind      - Create kind cluster + build/load images"
	@echo "  make deploy-kind     - Deploy Portfolio to kind cluster"
	@echo "  make logs-kind       - Show logs from kind deployment"
	@echo "  make clean-kind      - Delete kind cluster"
	@echo ""
	@echo "MINIKUBE:"
	@echo "  make build-minikube  - Start minikube + build images"
	@echo "  make deploy-minikube - Deploy Portfolio to minikube"
	@echo "  make logs-minikube   - Show logs from minikube deployment"
	@echo "  make clean-minikube  - Stop minikube"
	@echo ""
	@echo "General:"
	@echo "  make test           - Test the deployment"
	@echo "  make port-forward   - Port forward services (if no ingress)"

# KIND targets
build-kind:
	@echo "🔨 Creating kind cluster with nginx ingress..."
	kind create cluster --name portfolio
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	kubectl wait --namespace ingress-nginx --for=condition=Ready pods --selector=app.kubernetes.io/component=controller --timeout=120s
	@echo "🐳 Building and loading Docker images..."
	docker build -t ghcr.io/shadow-link-industries/portfolio-api:local ./api
	docker build -t ghcr.io/shadow-link-industries/portfolio-ui:local ./ui
	kind load docker-image ghcr.io/shadow-link-industries/portfolio-api:local --name portfolio
	kind load docker-image ghcr.io/shadow-link-industries/portfolio-ui:local --name portfolio
	@echo "✅ Kind cluster ready!"

deploy-kind: build-kind
	@echo "🚀 Deploying Portfolio to kind..."
	kubectl apply -k k8s/overlays/local
	@echo "⏳ Waiting for pods to be ready..."
	kubectl -n portfolio wait --for=condition=Ready pods --all --timeout=300s
	@echo "✅ Deployment complete!"
	@echo "🌐 Open http://portfolio.localtest.me"
	@echo "🔍 Health: curl -s http://portfolio.localtest.me/api/health"

# MINIKUBE targets  
build-minikube:
	@echo "🔨 Starting minikube with ingress..."
	minikube start
	minikube addons enable ingress
	@echo "🐳 Building Docker images in minikube..."
	eval $$(minikube docker-env) && \
	docker build -t ghcr.io/shadow-link-industries/portfolio-api:local ./api && \
	docker build -t ghcr.io/shadow-link-industries/portfolio-ui:local ./ui
	@echo "✅ Minikube ready!"

deploy-minikube: build-minikube
	@echo "🚀 Deploying Portfolio to minikube..."
	kubectl apply -k k8s/overlays/local
	@echo "⏳ Waiting for pods to be ready..."
	kubectl -n portfolio wait --for=condition=Ready pods --all --timeout=300s
	@echo "✅ Deployment complete!"
	@echo "🌐 Add to /etc/hosts: echo \"$$(minikube ip) portfolio.localtest.me\" | sudo tee -a /etc/hosts"
	@echo "🌐 Then open http://portfolio.localtest.me"

# Logging and monitoring
logs-kind logs-minikube:
	@echo "📊 Portfolio API logs:"
	kubectl -n portfolio logs -l app=portfolio-api --tail=50
	@echo ""
	@echo "📊 Portfolio UI logs:"
	kubectl -n portfolio logs -l app=portfolio-ui --tail=20

# Testing
test:
	@echo "🧪 Testing Portfolio deployment..."
	@echo "Checking API health..."
	kubectl -n portfolio get pods
	kubectl -n portfolio exec deploy/portfolio-api -- curl -f http://localhost:8000/health || echo "❌ API health check failed"
	@echo "Checking UI..."
	kubectl -n portfolio exec deploy/portfolio-ui -- curl -f http://localhost:5173/ || echo "❌ UI health check failed"

# Port forwarding (if ingress doesn't work)
port-forward:
	@echo "🔗 Port forwarding services..."
	@echo "UI: http://localhost:5173"
	@echo "API: http://localhost:8000"
	kubectl -n portfolio port-forward svc/portfolio-ui 5173:80 &
	kubectl -n portfolio port-forward svc/portfolio-api 8000:80 &
	@echo "Press Ctrl+C to stop port forwarding"

# Cleanup
clean-kind:
	@echo "🧹 Deleting kind cluster..."
	kind delete cluster --name portfolio

clean-minikube:
	@echo "🧹 Stopping minikube..."
	minikube stop
	minikube delete

# Status
status:
	@echo "📊 Portfolio Status:"
	kubectl -n portfolio get pods,svc,ing
	@echo ""
	kubectl -n portfolio describe ing portfolio-ingress