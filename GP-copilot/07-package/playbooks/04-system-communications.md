# Playbook 04: System & Communications Protection
### Controls: SC-7, SC-8, SC-12, SC-28

---

## WHAT THIS COVERS

| Control | Name | What the assessor checks |
|---------|------|------------------------|
| SC-7 | Boundary Protection | Network segmentation exists, ingress/egress controlled |
| SC-8 | Transmission Confidentiality | Data in transit is encrypted (TLS) |
| SC-12 | Cryptographic Key Management | Keys are managed securely (KMS, rotation) |
| SC-28 | Protection at Rest | Data at rest is encrypted |

**SC-7 is the most common MISSING control on first scan.** If you have a flat network with no NetworkPolicies, this is your #1 priority.

---

## SC-7: BOUNDARY PROTECTION (NETWORK SEGMENTATION)

### What "compliant" looks like
- Default-deny network policy in every namespace
- Explicit allow rules for each required communication path
- External traffic only enters through defined ingress points
- Egress to internet is controlled and logged

### Step 1: Audit current network state

```bash
# Check for existing NetworkPolicies
kubectl get networkpolicies -A
# If this returns nothing → you have a flat network → SC-7 is MISSING

# Find all services and their communication patterns
kubectl get svc -A -o custom-columns=\
"NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,PORTS:.spec.ports[*].port"

# Find external-facing services
kubectl get svc -A -o json | \
  jq -r '.items[] | select(.spec.type=="LoadBalancer" or .spec.type=="NodePort") |
    "EXTERNAL: " + .metadata.namespace + "/" + .metadata.name + " (" + .spec.type + ")"'

# Map pod-to-pod traffic (if service mesh installed)
# Kiali dashboard or istioctl analyze
```

### Step 2: Deploy default-deny in every namespace

```yaml
# default-deny.yaml — apply to EVERY application namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: <namespace>
spec:
  podSelector: {}           # Applies to all pods
  policyTypes:
    - Ingress
    - Egress
---
# Allow DNS (required for service discovery)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

```bash
# Apply to all app namespaces
for ns in $(kubectl get ns -l platform.gp.io/team -o jsonpath='{.items[*].metadata.name}'); do
  echo "Applying default-deny to $ns"
  cat default-deny.yaml | sed "s/<namespace>/$ns/" | kubectl apply -f -
done
```

### Step 3: Add explicit allow rules for each service

```yaml
# Example: payments-api can receive traffic from checkout-api on port 8080
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-checkout-to-payments
  namespace: payments
spec:
  podSelector:
    matchLabels:
      app: payments-api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: checkout
          podSelector:
            matchLabels:
              app: checkout-api
      ports:
        - protocol: TCP
          port: 8080
---
# Example: payments-api can reach the database on port 5432
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-payments-to-db
  namespace: payments
spec:
  podSelector:
    matchLabels:
      app: payments-api
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: payments-db
      ports:
        - protocol: TCP
          port: 5432
---
# Example: allow ingress from the gateway (external traffic)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-gateway-ingress
  namespace: payments
spec:
  podSelector:
    matchLabels:
      app: payments-api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-system
      ports:
        - protocol: TCP
          port: 8080
```

### Step 4: Allow Prometheus scraping

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus-scrape
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - protocol: TCP
          port: 8080    # metrics port
```

### Step 5: Verify segmentation works

```bash
# Test from inside a pod — should be BLOCKED
kubectl exec -it -n checkout deploy/checkout-api -- \
  curl -s --max-time 3 http://payments-api.payments:8080/health
# Expected: timeout (if not allowed) or 200 (if allowed)

# Test DNS still works
kubectl exec -it -n checkout deploy/checkout-api -- \
  nslookup payments-api.payments.svc.cluster.local
```

Use the templates from:
`templates/remediation-templates/network-policies.yaml`

---

## SC-8: TRANSMISSION CONFIDENTIALITY (TLS EVERYWHERE)

### What "compliant" looks like
- All external traffic is TLS 1.2+ encrypted
- Internal pod-to-pod traffic is encrypted (mTLS via service mesh or app-level TLS)
- No plaintext HTTP endpoints in production
- Certificates are managed automatically

### Step 1: External TLS (ingress)

```yaml
# Gateway API with TLS termination
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: ingress-system
spec:
  gatewayClassName: istio  # or nginx, envoy, etc.
  listeners:
    - name: https
      port: 443
      protocol: HTTPS
      tls:
        mode: Terminate
        certificateRefs:
          - name: wildcard-tls
            kind: Secret
      allowedRoutes:
        namespaces:
          from: All
    - name: http-redirect
      port: 80
      protocol: HTTP
      # Redirect all HTTP to HTTPS
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: payments-route
  namespace: payments
spec:
  parentRefs:
    - name: main-gateway
      namespace: ingress-system
  hostnames:
    - "payments.app.example.com"
  rules:
    - backendRefs:
        - name: payments-api
          port: 8080
```

### Step 2: Internal mTLS (service mesh)

**Option A: Istio**
```bash
# Install Istio
istioctl install --set profile=default

# Enable mTLS cluster-wide
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
EOF

# Label namespaces for sidecar injection
kubectl label namespace payments istio-injection=enabled
kubectl label namespace checkout istio-injection=enabled

# Restart deployments to pick up sidecars
kubectl rollout restart deployment -n payments
kubectl rollout restart deployment -n checkout

# Verify mTLS is active
istioctl authn tls-check payments-api.payments
```

**Option B: No service mesh — app-level TLS**

If you can't deploy a service mesh, applications must handle TLS themselves:
```yaml
# Mount TLS certs into pods
volumes:
  - name: tls-certs
    secret:
      secretName: app-tls-cert
containers:
  - name: app
    volumeMounts:
      - name: tls-certs
        mountPath: /etc/tls
        readOnly: true
    env:
      - name: TLS_CERT_PATH
        value: /etc/tls/tls.crt
      - name: TLS_KEY_PATH
        value: /etc/tls/tls.key
```

### Step 3: Verify no plaintext

```bash
# Check all services — none should be HTTP-only in prod
kubectl get svc -n <namespace> -o json | \
  jq -r '.items[] | .metadata.name + ": " + (.spec.ports[]? | "\(.port)/\(.name // "unnamed")")'

# Test from inside cluster
kubectl exec -it <pod> -- curl -v http://payments-api:8080/health 2>&1 | grep -i "tls\|ssl\|https"
```

---

## SC-12: CRYPTOGRAPHIC KEY MANAGEMENT

### What "compliant" looks like
- Encryption keys are managed by a dedicated key management service (AWS KMS)
- Keys are rotated regularly (annual minimum)
- Key access is logged and auditable
- No hardcoded keys in code or config

### Step 1: Use AWS KMS for all encryption

```bash
# Create a KMS key for the application
aws kms create-key \
  --description "FedRAMP application encryption key" \
  --key-usage ENCRYPT_DECRYPT \
  --tags TagKey=compliance,TagValue=fedramp TagKey=application,TagValue=<app-name>

# Enable automatic annual rotation
aws kms enable-key-rotation --key-id <key-id>

# Verify rotation is enabled
aws kms get-key-rotation-status --key-id <key-id>
```

### Step 2: EKS secrets encryption with KMS

```bash
# Enable envelope encryption for K8s Secrets
aws eks associate-encryption-config \
  --cluster-name <cluster> \
  --encryption-config '[{
    "resources": ["secrets"],
    "provider": {"keyArn": "arn:aws:kms:us-east-1:123456789:key/<key-id>"}
  }]'

# Verify
aws eks describe-cluster --name <cluster> \
  --query 'cluster.encryptionConfig'
```

### Step 3: Scan for hardcoded keys

```bash
# Run Gitleaks
gitleaks detect --source . --report-format json --report-path gitleaks-report.json

# Review findings
cat gitleaks-report.json | jq '.[].Description'

# If findings exist → rotate the exposed key → move to AWS Secrets Manager
```

---

## SC-28: PROTECTION AT REST

### What "compliant" looks like
- All storage is encrypted at rest (EBS, S3, RDS, EFS)
- K8s Secrets are encrypted at rest (KMS envelope encryption)
- Database storage is encrypted
- Backups are encrypted

### Step 1: Audit current encryption status

```bash
# Check S3 bucket encryption
for bucket in $(aws s3api list-buckets --query 'Buckets[*].Name' --output text); do
  enc=$(aws s3api get-bucket-encryption --bucket "$bucket" 2>/dev/null | \
    jq -r '.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' 2>/dev/null)
  echo "$bucket: ${enc:-NOT ENCRYPTED}"
done

# Check EBS volume encryption
aws ec2 describe-volumes --query 'Volumes[*].[VolumeId,Encrypted,Size]' --output table

# Check RDS encryption
aws rds describe-db-instances \
  --query 'DBInstances[*].[DBInstanceIdentifier,StorageEncrypted,KmsKeyId]' --output table

# Check EFS encryption
aws efs describe-file-systems \
  --query 'FileSystems[*].[FileSystemId,Encrypted,KmsKeyId]' --output table
```

### Step 2: Enable encryption where missing

```bash
# S3: Enable default encryption on all buckets
for bucket in $(aws s3api list-buckets --query 'Buckets[*].Name' --output text); do
  aws s3api put-bucket-encryption --bucket "$bucket" \
    --server-side-encryption-configuration '{
      "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "aws:kms", "KMSMasterKeyID": "<key-id>"}}]
    }'
  echo "Encrypted: $bucket"
done

# S3: Block public access on all buckets
for bucket in $(aws s3api list-buckets --query 'Buckets[*].Name' --output text); do
  aws s3api put-public-access-block --bucket "$bucket" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
done

# EBS: Enable default encryption for new volumes
aws ec2 enable-ebs-encryption-by-default --region us-east-1
```

### Step 3: Verify PersistentVolumes in K8s are encrypted

```bash
# Check StorageClass encryption
kubectl get storageclass -o json | \
  jq -r '.items[] | .metadata.name + ": encrypted=" + (.parameters.encrypted // "not set")'

# Create encrypted StorageClass if needed
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: encrypted-gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  kmsKeyId: <key-arn>
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
```

---

## EVIDENCE FOR THE ASSESSOR

| Evidence | Command/Source | Control |
|----------|---------------|---------|
| NetworkPolicy list per namespace | `kubectl get netpol -A` | SC-7 |
| Default-deny proof | Policy YAML + test showing blocked traffic | SC-7 |
| TLS certificate details | `kubectl get certificates` or cert-manager | SC-8 |
| mTLS proof (Istio) | `istioctl authn tls-check` | SC-8 |
| KMS key configuration | `aws kms describe-key` + rotation status | SC-12 |
| EKS secret encryption | `aws eks describe-cluster` encryption config | SC-12 |
| Gitleaks scan (no hardcoded keys) | Gitleaks report JSON | SC-12 |
| S3 encryption status | Bucket encryption audit output | SC-28 |
| EBS encryption status | Volume encryption audit output | SC-28 |
| RDS encryption status | `aws rds describe-db-instances` | SC-28 |

---

## COMPLETION CHECKLIST

```
[ ] SC-7:  Default-deny NetworkPolicy in every app namespace
[ ] SC-7:  Explicit allow rules for each communication path
[ ] SC-7:  No NodePort services in production
[ ] SC-7:  External traffic only enters through Gateway/Ingress
[ ] SC-7:  Egress to internet is controlled
[ ] SC-8:  All external endpoints are HTTPS (TLS 1.2+)
[ ] SC-8:  HTTP→HTTPS redirect configured
[ ] SC-8:  Internal traffic encrypted (mTLS or app-level TLS)
[ ] SC-8:  cert-manager managing certificate lifecycle
[ ] SC-12: AWS KMS used for all encryption keys
[ ] SC-12: Key rotation enabled (annual minimum)
[ ] SC-12: No hardcoded keys in code (Gitleaks clean)
[ ] SC-12: EKS Secrets encrypted with KMS envelope encryption
[ ] SC-28: All S3 buckets encrypted (KMS)
[ ] SC-28: All EBS volumes encrypted
[ ] SC-28: All RDS instances encrypted
[ ] SC-28: Default EBS encryption enabled for region
[ ] SC-28: StorageClass configured with encryption
```
