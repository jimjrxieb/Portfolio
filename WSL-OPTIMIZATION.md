# WSL Resource Optimization for HP Spectre

## Current Setup
- HP Spectre laptop running WSL2
- KinD cluster for local development  
- Docker + Kubernetes workloads

## Performance Optimization

### 1. Cap WSL Memory & CPU
Create/edit `C:\Users\<username>\.wslconfig`:

```ini
[wsl2]
memory=4GB
processors=4
swap=1GB
localhostForwarding=true
```

Then restart WSL:
```powershell
wsl --shutdown
# Wait 10 seconds, then restart WSL
```

### 2. Lean Kubernetes Stack
Current approach already optimized:
- ✅ KinD (single node)
- ✅ ingress-nginx only
- ✅ No ArgoCD (removed)
- ✅ Chroma disabled in dev
- ✅ No Prometheus/Grafana

### 3. Docker Optimization
In Docker Desktop:
- Resources → Advanced
- Memory: 4GB max
- CPU: 4 cores max
- Disk image size: 64GB

### 4. Alternative: k3d (Future)
For even lighter footprint, consider k3d next iteration:
```bash
# Install k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Create lightweight cluster
k3d cluster create portfolio --port "80:80@loadbalancer" --port "443:443@loadbalancer"
```

### 5. Development Workflow
Keep workloads minimal during development:
- API + UI containers only
- Disable AI/ML features until needed
- Use external services (OpenAI) instead of local models

### 6. Monitoring Resources
```bash
# WSL memory usage
wsl -l -v
free -h

# Docker stats
docker stats

# Kubernetes resource usage  
kubectl top nodes
kubectl top pods -A
```

## Expected Performance
With these optimizations:
- WSL memory: ~3GB used
- Docker: ~2GB containers
- Available: ~3GB for host OS
- Build time: 2-3 minutes
- Deploy time: 30-60 seconds