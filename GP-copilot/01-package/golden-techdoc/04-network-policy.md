# 04 — Network Policy (Zero-Trust)

Every namespace starts with default-deny. You explicitly allow
only the traffic your app needs.

## The Pattern

```
1. Deny everything (platform default)
2. Allow DNS (required for service discovery)
3. Allow ingress controller → your pods
4. Allow pod-to-pod within your namespace
5. Allow outbound HTTPS (if your app calls external APIs)
```

---

## Template

```yaml
{{- if .Values.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}
  policyTypes:
    - Ingress
    - Egress

  ingress:
    # Allow from ingress controller (Gateway API / Traefik)
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: {{ .Values.networkPolicy.ingressNamespace }}
      ports:
        - protocol: TCP
          port: {{ .Values.api.service.targetPort }}
        - protocol: TCP
          port: {{ .Values.ui.service.targetPort }}

    # Allow pod-to-pod within namespace
    - from:
        - podSelector:
            matchLabels:
              {{- include "myapp.selectorLabels" . | nindent 14 }}
      ports:
        - protocol: TCP
          port: {{ .Values.api.service.targetPort }}
        - protocol: TCP
          port: {{ .Values.ui.service.targetPort }}
        - protocol: TCP
          port: {{ .Values.db.service.targetPort }}

  egress:
    # DNS (required)
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53

    # Internal pod-to-pod
    - to:
        - podSelector:
            matchLabels:
              {{- include "myapp.selectorLabels" . | nindent 14 }}

    # External HTTPS only (API calls to Claude, OpenAI, Stripe, etc.)
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 10.0.0.0/8
              - 172.16.0.0/12
              - 192.168.0.0/16
      ports:
        - protocol: TCP
          port: 443
{{- end }}
```

### Values

```yaml
networkPolicy:
  enabled: true
  ingressNamespace: kube-system    # Where the ingress controller runs
```

> **Ask your platform engineer** which namespace the ingress controller
> runs in. It's usually `kube-system` (K3s/Traefik) or `gateway-system`
> (standalone Envoy/Cilium).

---

## What Each Rule Does

### Ingress Rules (Who Can Talk TO Your Pods)

| Rule | Purpose | Remove If |
|------|---------|-----------|
| From ingress controller namespace | Gateway/HTTPRoute can reach your app | Never — you need external traffic |
| From same-namespace pods | API ↔ DB, UI ↔ API communication | Single-container app |

### Egress Rules (Who Your Pods Can Talk TO)

| Rule | Purpose | Remove If |
|------|---------|-----------|
| DNS (UDP/TCP 53) | Service discovery (`svc.cluster.local`) | Never — everything breaks without DNS |
| Same-namespace pods | Internal communication | Single-container app |
| External HTTPS (443) | Claude API, OpenAI, Stripe, etc. | App makes no external API calls |

---

## Tightening Further

### Restrict External Egress to Specific IPs

If you know exactly which external APIs you call:

```yaml
# Instead of 0.0.0.0/0, use specific CIDRs
egress:
  - to:
      - ipBlock:
          cidr: 104.18.0.0/16     # Cloudflare (Anthropic API)
      - ipBlock:
          cidr: 13.107.0.0/16     # Azure (OpenAI API)
    ports:
      - protocol: TCP
        port: 443
```

### Deny All Egress (Fully Internal App)

```yaml
egress:
  # DNS only — no external access
  - to:
      - namespaceSelector: {}
    ports:
      - protocol: UDP
        port: 53
      - protocol: TCP
        port: 53
  # Internal only
  - to:
      - podSelector:
          matchLabels:
            {{- include "myapp.selectorLabels" . | nindent 14 }}
```

---

## Testing Your Policy

```bash
# Deploy a debug pod in your namespace
kubectl run nettest --rm -it --image=busybox -n your-namespace -- sh

# Test DNS (should work)
nslookup your-api-service

# Test internal service (should work)
wget -qO- http://your-api-service:8000/health

# Test external HTTPS (should work if allowed)
wget -qO- https://api.anthropic.com/ --timeout=3

# Test blocked port (should timeout/fail)
wget -qO- http://evil.com:8080 --timeout=3
```

---

## Common Mistakes

1. **Forgot DNS egress** — Everything breaks. Services can't resolve. Always allow UDP/TCP 53.
2. **Wrong ingress namespace** — If the ingress controller is in `gateway-system` but you wrote `kube-system`, no traffic gets through.
3. **Missing pod-to-pod** — Your API can't reach your database within the same namespace.
4. **Too broad egress** — `0.0.0.0/0` on all ports is no policy at all. Restrict to port 443 at minimum.
5. **Forgot `policyTypes`** — Without `policyTypes: [Ingress, Egress]`, only ingress rules apply.
