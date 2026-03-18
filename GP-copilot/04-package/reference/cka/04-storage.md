# CKA Domain 4: Storage (10%)

Understand storage classes, persistent volumes. Understand volume mode, access modes, and reclaim policies for volumes. Understand persistent volume claims. Know how to configure applications with persistent storage.

## CKA Exam Quick Reference

### PersistentVolume
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-data
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteOnce        # RWO — single node
  # - ReadOnlyMany       # ROX — multiple nodes read-only
  # - ReadWriteMany      # RWX — multiple nodes read-write
  persistentVolumeReclaimPolicy: Retain  # Retain | Delete | Recycle
  storageClassName: manual
  hostPath:
    path: /data/pv-data
```

### PersistentVolumeClaim
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-data
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: manual
```

### Pod with PVC
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-storage
spec:
  containers:
  - name: app
    image: nginx:1.25
    volumeMounts:
    - name: data
      mountPath: /usr/share/nginx/html
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: pvc-data
```

### StorageClass
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs   # or csi driver
parameters:
  type: gp3
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

### Volume Types (Common)
```yaml
# emptyDir — temp storage, deleted with pod
volumes:
- name: tmp
  emptyDir: {}

# hostPath — node filesystem (testing only)
volumes:
- name: data
  hostPath:
    path: /data
    type: DirectoryOrCreate

# configMap as volume
volumes:
- name: config
  configMap:
    name: app-config

# secret as volume
volumes:
- name: creds
  secret:
    secretName: db-creds
```

### StatefulSet with Volume Claims
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 20Gi
```

### Imperative Commands
```bash
# Check PVs and PVCs
kubectl get pv
kubectl get pvc -A

# Describe bound volumes
kubectl describe pv pv-data
kubectl describe pvc pvc-data

# Check which pod uses a PVC
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName=="pvc-data") | .metadata.name'
```

### Expand a PVC
```bash
# StorageClass must have allowVolumeExpansion: true
kubectl patch pvc pvc-data -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

## Cross-Reference to GP-CONSULTING

| Need | Location |
|------|----------|
| ResourceQuota for storage | `02-CLUSTER-HARDENING/templates/golden-path/base/resourcequota.yaml` |
| Golden path deployment | `02-CLUSTER-HARDENING/templates/golden-path/` |

## Practice Scenarios

1. **PV + PVC**: Create a PV, create a PVC that binds to it, use it in a pod
2. **StorageClass**: Create a StorageClass with dynamic provisioning, claim storage
3. **StatefulSet**: Deploy a 3-replica StatefulSet with per-replica volumes
4. **Reclaim policy**: Test Retain vs Delete — delete PVC, observe PV state
5. **Volume expansion**: Expand a PVC from 5Gi to 20Gi without downtime
6. **Troubleshoot**: Fix a PVC stuck in Pending (wrong StorageClass, capacity mismatch)
