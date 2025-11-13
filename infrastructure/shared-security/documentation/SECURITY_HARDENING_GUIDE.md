# Security Hardening Implementation Guide

## Overview

This guide provides step-by-step instructions for implementing the security configurations in this repository.

## Prerequisites

- Kubernetes cluster (1.23+)
- kubectl configured and connected
- Cluster admin permissions
- kube-bench tool installed

## Implementation Steps

### 1. Network Security (Zero Trust)

#### Deploy Default Deny Policy
```bash
kubectl apply -f kubernetes/network-policies/default-deny-all.yaml
```

#### Allow Essential DNS Traffic
```bash
kubectl apply -f kubernetes/network-policies/allow-dns.yaml
```

#### Verification
```bash
# Check policies are active
kubectl get networkpolicies --all-namespaces

# Test connectivity (should fail for unallowed traffic)
kubectl run test-pod --image=busybox --rm -it -- wget -O- google.com
```

### 2. Pod Security Standards

#### Apply PSS Configuration
```bash
kubectl apply -f kubernetes/pod-security/security-standards.yaml
```

#### Verification
```bash
# Check namespace labels
kubectl get namespace default -o yaml | grep security

# Try deploying a privileged pod (should fail)
kubectl run privileged-test --image=nginx --privileged
```

### 3. RBAC Hardening

#### Deploy Service Accounts
```bash
kubectl apply -f kubernetes/rbac/service-accounts.yaml
```

#### Apply Roles and Bindings
```bash
kubectl apply -f kubernetes/rbac/roles.yaml
kubectl apply -f kubernetes/rbac/role-bindings.yaml
```

#### Verification
```bash
# Check RBAC permissions
kubectl auth can-i --list --as=system:serviceaccount:default:app-service-account
```

### 4. Node Hardening

#### Apply Kubelet Configuration
```bash
sudo cp kubernetes/node-hardening/kubelet-config.yaml /etc/kubernetes/
```

#### Run CIS Hardening Script
```bash
sudo chmod +x scripts/kube-bench-remediation.sh
sudo ./scripts/kube-bench-remediation.sh
```

#### Verification
```bash
# Run kube-bench to verify fixes
kube-bench --config-dir=/etc/kube-bench/cfg --config=cis-1.6
```

## Security Validation

### Complete System Check
```bash
# Network policies
kubectl get networkpolicies --all-namespaces

# Pod security
kubectl get podsecuritypolicy

# RBAC
kubectl get roles,rolebindings,serviceaccounts --all-namespaces

# Node security
systemctl status kubelet
```

### Security Testing

#### Test Network Policies
```bash
# Should succeed (DNS allowed)
kubectl run test-dns --image=busybox --rm -it -- nslookup google.com

# Should fail (HTTP blocked)
kubectl run test-http --image=busybox --rm -it -- wget google.com
```

#### Test Pod Security
```bash
# Should fail (privileged not allowed)
kubectl run privileged-test --image=nginx --privileged

# Should succeed (compliant pod)
kubectl run secure-test --image=nginx
```

## Troubleshooting

### Common Issues

#### NetworkPolicy Blocks Legitimate Traffic
```bash
# Check existing policies
kubectl describe networkpolicy -n <namespace>

# Add specific allow rule if needed
# Edit allow-dns.yaml or create new policy
```

#### Pod Security Violations
```bash
# Check pod security events
kubectl get events --field-selector reason=FailedCreate

# Review pod security context requirements
kubectl explain pod.spec.securityContext
```

#### RBAC Permission Denied
```bash
# Check current permissions
kubectl auth can-i <verb> <resource> --as=<user/serviceaccount>

# Review role definitions
kubectl describe role <role-name>
```

## Monitoring and Maintenance

### Security Metrics
- Monitor NetworkPolicy effectiveness
- Track pod security violations
- Review RBAC access patterns
- Validate CIS compliance regularly

### Regular Tasks
1. **Weekly**: Review security events
2. **Monthly**: Update security reports
3. **Quarterly**: Re-run CIS benchmark
4. **As needed**: Adjust policies for new services

## Advanced Configuration

### Custom Network Policies
Create application-specific policies:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-to-db
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
```

### Enhanced RBAC
Create fine-grained roles:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

## Security Best Practices

1. **Principle of Least Privilege**: Grant minimal required permissions
2. **Defense in Depth**: Implement multiple security layers
3. **Regular Updates**: Keep security configurations current
4. **Continuous Monitoring**: Watch for security events
5. **Documentation**: Maintain clear security procedures

---

Follow this guide to implement comprehensive Kubernetes security hardening.
