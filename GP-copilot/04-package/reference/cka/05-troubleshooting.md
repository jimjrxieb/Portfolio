# CKA Domain 5: Troubleshooting (30%)

Evaluate cluster and node logging. Understand how to monitor applications. Manage container stdout and stderr logs. Troubleshoot application failure. Troubleshoot cluster component failure. Troubleshoot networking.

## CKA Exam Quick Reference

### Cluster Component Health
```bash
# Control plane pods
kubectl get pods -n kube-system

# Component status (deprecated but still useful)
kubectl get componentstatuses

# Node status
kubectl get nodes -o wide
kubectl describe node <node-name>

# Check kubelet
systemctl status kubelet
journalctl -u kubelet --no-pager -l --since "10 minutes ago"

# Check static pod manifests
ls /etc/kubernetes/manifests/
# kube-apiserver.yaml, kube-controller-manager.yaml, kube-scheduler.yaml, etcd.yaml
```

### Pod Debugging
```bash
# Pod status overview
kubectl get pods -A -o wide

# Detailed pod info
kubectl describe pod <pod> -n <ns>

# Pod logs
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous     # crashed container
kubectl logs <pod> -n <ns> -c <container>  # specific container

# Exec into pod
kubectl exec -it <pod> -n <ns> -- /bin/sh

# Ephemeral debug container (K8s 1.25+)
kubectl debug -it <pod> -n <ns> --image=busybox --target=<container>

# Debug node
kubectl debug node/<node-name> -it --image=busybox
```

### Common Pod Issues

| Symptom | Check | Fix |
|---------|-------|-----|
| **ImagePullBackOff** | `kubectl describe pod` — image name, registry auth | Fix image name, create imagePullSecret |
| **CrashLoopBackOff** | `kubectl logs --previous` — app crash reason | Fix app config, command, or OOM limits |
| **Pending** | `kubectl describe pod` — scheduling failures | Fix taints/tolerations, resource requests, node capacity |
| **OOMKilled** | `kubectl describe pod` — last state | Increase memory limits |
| **CreateContainerError** | `kubectl describe pod` — volume mount, config issues | Fix ConfigMap/Secret references |
| **Init:Error** | `kubectl logs <pod> -c <init-container>` | Fix init container command |

### Events
```bash
# Namespace events (sorted by time)
kubectl get events -n <ns> --sort-by='.lastTimestamp'

# All events with warnings
kubectl get events -A --field-selector type=Warning

# Watch events
kubectl get events -n <ns> -w
```

### Network Debugging
```bash
# DNS test
kubectl run dns-test --image=busybox --rm -it -- nslookup kubernetes.default

# Connectivity test
kubectl run net-test --image=busybox --rm -it -- wget -qO- http://service-name.namespace:port

# Check service endpoints
kubectl get endpoints <service-name> -n <ns>

# Check if service selector matches pods
kubectl get pods -n <ns> -l <selector-key>=<selector-value>

# Check kube-proxy
kubectl -n kube-system get pods -l k8s-app=kube-proxy
kubectl -n kube-system logs -l k8s-app=kube-proxy

# Check CoreDNS
kubectl -n kube-system get pods -l k8s-app=kube-dns
kubectl -n kube-system logs -l k8s-app=kube-dns

# iptables rules (on node)
iptables-save | grep <service-clusterip>
```

### Node Troubleshooting
```bash
# Node conditions
kubectl describe node <node> | grep -A5 Conditions

# Common node issues:
# NotReady — kubelet down, CNI broken, disk pressure
# MemoryPressure — node running out of memory
# DiskPressure — node running out of disk
# PIDPressure — too many processes

# Fix NotReady node
ssh <node>
systemctl status kubelet
systemctl restart kubelet
journalctl -u kubelet --no-pager -l

# Check disk
df -h
# Check memory
free -m
# Check processes
top
```

### Control Plane Troubleshooting
```bash
# API server not responding
# Check if static pod is running
crictl ps | grep kube-apiserver
# Check manifest
cat /etc/kubernetes/manifests/kube-apiserver.yaml
# Check logs
crictl logs <container-id>

# Scheduler not scheduling
kubectl -n kube-system logs kube-scheduler-<node>
# Check manifest
cat /etc/kubernetes/manifests/kube-scheduler.yaml

# Controller manager not reconciling
kubectl -n kube-system logs kube-controller-manager-<node>

# etcd issues
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### Application Logging
```bash
# Sidecar pattern for log collection
# Main container writes to /var/log/app.log
# Sidecar container tails and ships to stdout
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-logging
spec:
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: logs
      mountPath: /var/log
  - name: log-sidecar
    image: busybox
    command: ["sh", "-c", "tail -f /var/log/app.log"]
    volumeMounts:
    - name: logs
      mountPath: /var/log
  volumes:
  - name: logs
    emptyDir: {}
```

### Jsonpath — Extract Specific Fields
```bash
# Pod IPs
kubectl get pods -o jsonpath='{.items[*].status.podIP}'

# Node internal IPs
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'

# Sort pods by restart count
kubectl get pods --sort-by='.status.containerStatuses[0].restartCount'

# Get pods using more than 100m CPU
kubectl top pods --sort-by=cpu
```

## Cross-Reference to GP-CONSULTING

| Need | Location |
|------|----------|
| Event watcher | `03-DEPLOY-RUNTIME/watchers/watch-events.sh` |
| Drift detection | `03-DEPLOY-RUNTIME/watchers/watch-drift.sh` |
| Health check | `03-DEPLOY-RUNTIME/tools/health-check.sh` |
| Debug finding | `03-DEPLOY-RUNTIME/tools/debug-finding.sh` |
| Dataplane watcher | `03-DEPLOY-RUNTIME/watchers/watch-dataplane.sh` |
| Capture forensics | `03-DEPLOY-RUNTIME/responders/capture-forensics.sh` |
| Cluster report | `02-CLUSTER-HARDENING/tools/hardening/collect-cluster-report.sh` |

## Practice Scenarios

1. **Broken kubelet**: SSH to a node where kubelet is down, diagnose and fix
2. **Broken DNS**: CoreDNS is crashing, pods can't resolve services — find and fix
3. **Broken scheduler**: Pods stuck in Pending, scheduler has wrong config — fix manifest
4. **CrashLoopBackOff**: App starts and immediately crashes — use logs to find the config error
5. **Service not working**: Deployment exists, service exists, but no connectivity — fix selector mismatch
6. **OOMKilled**: Pod keeps restarting with OOMKilled — analyze memory usage, set correct limits
7. **Network isolation**: Pod can't reach another pod — check NetworkPolicies, DNS, endpoints
8. **etcd health**: etcd cluster unhealthy — diagnose using etcdctl, fix certificates or endpoints
