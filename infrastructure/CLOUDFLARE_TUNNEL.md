# Cloudflare Tunnel Configuration

## Active Tunnel Details

**Tunnel ID:** `17334a76-6f89-43ef-bbae-9dfb19aa5815`
**Tunnel Name:** LinkOps
**Status:** CONNECTED ✅
**Created:** 2025-11-09

### Connector Details

- **Connector ID:** `f1accb3d-04eb-4001-ae8a-c826e44e1371`
- **Version:** 2025.9.1
- **Platform:** linux_amd64
- **Hostname:** Jimjrx
- **Origin IP:** 23.122.170.195
- **Private IP:** 172.28.94.51

### Data Centers (Edge Locations)

- atl11 (Atlanta)
- atl01 (Atlanta)
- atl12 (Atlanta)
- atl08 (Atlanta)

### Configuration

**Config File:** `/home/jimmie/.cloudflared/config.yml`

```yaml
tunnel: 0f0fa0ed-f3c9-4b1e-8406-b6981bda53a5
credentials-file: /home/jimmie/.cloudflared/credentials.json

ingress:
  - hostname: linksmlm.com
    service: http://localhost:8080
  - service: http_status:404
```

### Public Hostname Routing

| Hostname | Service | Status |
|----------|---------|--------|
| linksmlm.com | http://localhost:8080 | Active |

The tunnel routes traffic from `linksmlm.com` to the local Kubernetes ingress running on port 8080.

### Running the Tunnel

**Start Command:**
```bash
/home/jimmie/.local/bin/cloudflared tunnel run --token <TUNNEL_TOKEN>
```

**Current Token (sensitive - use from environment):**
```bash
cloudflared tunnel run --token eyJhIjoiMjFhNWIyNzhmOGU1NTA2NzhlMGIyYThjNmZiNWE5M2EiLCJ0IjoiMTczMzRhNzYtNmY4OS00M2VmLWJiYWUtOWRmYjE5YWE1ODE1IiwicyI6Ik4yWmxaVGs0TXpjdFl6UTFOaTAwTkRkbExUaGhZall0T1dVNVpUa3lZekppTkdRMCJ9
```

### Health Check

View tunnel status:
```bash
# Check tunnel connector status
curl -s https://linksmlm.com | head -20

# View metrics (when tunnel is running)
curl -s http://127.0.0.1:20241/metrics
```

### Troubleshooting

If tunnel shows "control stream encountered a failure":
1. Ensure the tunnel token matches the one in Cloudflare dashboard
2. Verify localhost:8080 is accessible (`curl http://localhost:8080`)
3. Check that Kubernetes port-forward is running:
   ```bash
   kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
   ```

### Notes

- The tunnel is configured via Cloudflare dashboard under Zero Trust > Access > Tunnels
- Token-based authentication (no cert.pem required)
- Automatic updates enabled (24h check frequency)
- ICMP proxy disabled (requires elevated privileges)
