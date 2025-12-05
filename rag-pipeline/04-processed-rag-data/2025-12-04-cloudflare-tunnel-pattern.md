# Cloudflare Tunnel Pattern - Docker Desktop K8s
Date: 2025-12-04

## Problem
Need to expose local Docker Desktop K8s to internet (linksmlm.com) without public IP or opening firewall ports.

## Architecture
```
linksmlm.com → Cloudflare Edge → cloudflared → localhost:8090 → port-forward → nginx-ingress → K8s services
```

## Key Components
1. **cloudflared process**: Makes outbound connection to Cloudflare (Zero Trust)
2. **kubectl port-forward**: Bridges localhost:8090 to nginx-ingress:80
3. **nginx ingress**: Routes based on Host header to services

## Config Files
**~/.cloudflared/config.yml:**
```yaml
tunnel: <tunnel-id>
credentials-file: ~/.cloudflared/credentials.json
ingress:
  - hostname: linksmlm.com
    service: http://localhost:8090
  - service: http_status:404
```

## Verification
```bash
curl -H "Host: linksmlm.com" http://localhost:8090/api/chat/health
```

## Trade-offs
- **Accepted**: Two processes must be running (cloudflared + port-forward)
- **Accepted**: No inbound ports needed (outbound only)
- **Avoided**: VPS/cloud hosting costs for development

## When to Use
- Local K8s exposed to internet for demos
- Development without public IP
- Zero Trust networking model

## Key Insight
Cloudflare Tunnel + kubectl port-forward bridges local K8s to the internet. Both processes must be running. Test with Host header before assuming it's live.
