#!/bin/bash
# Local Platform Information and Access Script

set -e

CLUSTER_NAME="portfolio-local"
NAMESPACE="linkops-portfolio"

echo "🎯 Local KinD Platform Status"
echo "=============================="

# Cluster info
echo ""
echo "🔧 Cluster Details:"
echo "  Name: $CLUSTER_NAME"
echo "  Context: kind-$CLUSTER_NAME"
echo "  Namespace: $NAMESPACE"

# Get ArgoCD admin password
echo ""
echo "🔐 ArgoCD Access:"
ARGO_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "  URL: https://localhost:8080"
echo "  Username: admin"
echo "  Password: $ARGO_PASSWORD"

# Check cluster status
echo ""
echo "📊 Cluster Status:"
kubectl get nodes --no-headers | awk '{print "  Node: " $1 " (" $2 ")"}'

echo ""
echo "🚀 Key Services:"
kubectl get pods -n argocd --no-headers | head -3 | awk '{print "  ArgoCD: " $1 " (" $3 ")"}'
kubectl get pods -n ingress-nginx --no-headers | head -1 | awk '{print "  Ingress: " $1 " (" $3 ")"}'

# Check portfolio application
echo ""
echo "📱 Portfolio Application:"
if kubectl get application portfolio -n argocd >/dev/null 2>&1; then
    APP_HEALTH=$(kubectl get application portfolio -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
    APP_SYNC=$(kubectl get application portfolio -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    echo "  Status: Health=$APP_HEALTH, Sync=$APP_SYNC"

    if kubectl get pods -n $NAMESPACE >/dev/null 2>&1; then
        echo "  Pods:"
        kubectl get pods -n $NAMESPACE --no-headers | awk '{print "    " $1 " (" $3 ")"}'
    else
        echo "  Pods: None deployed yet"
    fi
else
    echo "  Status: ArgoCD Application not found"
fi

echo ""
echo "🔗 Access Commands:"
echo "  ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Check Apps: kubectl get applications -n argocd"
echo "  View Logs: kubectl logs -f deployment/argocd-server -n argocd"

echo ""
echo "🛠️  Management Commands:"
echo "  Sync App: kubectl -n argocd patch application portfolio --type=merge --patch='{\"operation\":{\"sync\":{}}}'"
echo "  Delete App: kubectl delete application portfolio -n argocd"
echo "  Cleanup: kind delete cluster --name $CLUSTER_NAME"

echo ""
echo "📝 Next Steps:"
echo "  1. Start ArgoCD port-forward"
echo "  2. Access ArgoCD UI and check portfolio application"
echo "  3. Create development secrets if needed"
echo "  4. Test application deployment"
