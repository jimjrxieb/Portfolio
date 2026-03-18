# Playbook: Tune Falco

> Reduce false positives from ~500/day to <50/day, then load threat-specific detection rules.
>
> **When:** Week 2, after observe-only baseline.
> **Time:** ~30 min

---

## Step 1: Find the Noisy Rules

```bash
PKG=~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME

bash $PKG/tools/tune-falco.sh --show-top
```

Output example:
```
  Count  Rule
  ------  --------------------------------------------------
     234  Terminal shell in container
     156  Write below etc
      89  Contact K8s API Server From Container
      21  Read sensitive file untrusted
```

---

## Step 2: Apply the Base Allowlist

Suppresses common legitimate activity — monitoring agents, CI runners, log collectors, init containers:

```bash
# Preview
bash $PKG/tools/tune-falco.sh --add-allowlist $PKG/templates/falco-rules/allowlist.yaml --dry-run

# Apply
bash $PKG/tools/tune-falco.sh --add-allowlist $PKG/templates/falco-rules/allowlist.yaml
```

---

## Step 3: Load K8s Audit Rules

Detection for privilege escalation, RBAC changes, secret access:

```bash
bash $PKG/tools/tune-falco.sh --add-allowlist $PKG/templates/falco-rules/k8s-audit.yaml
```

Adds 8 MITRE ATT&CK-mapped rules:
- `Attach to cluster-admin Role` → CRITICAL
- `Create Privileged Pod` → CRITICAL
- `Create HostNetwork Pod` → HIGH
- `K8s Secret Accessed` → WARNING
- `Exec Into Container` → NOTICE
- `ClusterRole with Wildcard Created` → HIGH
- `NodePort Service Created` → WARNING
- `Kube-system ConfigMap Modified` → HIGH

---

## Step 4: Load Threat Detection Rules

Apply based on client risk profile:

```bash
# MITRE ATT&CK enrichment (adds tactic/technique tags to all alerts)
bash $PKG/tools/tune-falco.sh --add-allowlist $PKG/templates/falco-rules/mitre-mappings.yaml

# Crypto mining detection
bash $PKG/tools/tune-falco.sh --add-allowlist $PKG/templates/falco-rules/crypto-mining.yaml

# Data exfiltration
bash $PKG/tools/tune-falco.sh --add-allowlist $PKG/templates/falco-rules/data-exfiltration.yaml

# Privilege escalation
bash $PKG/tools/tune-falco.sh --add-allowlist $PKG/templates/falco-rules/privilege-escalation.yaml

# Persistence
bash $PKG/tools/tune-falco.sh --add-allowlist $PKG/templates/falco-rules/persistence.yaml
```

**Load all at once:**

```bash
for rule in mitre-mappings crypto-mining data-exfiltration privilege-escalation persistence; do
  bash $PKG/tools/tune-falco.sh --add-allowlist $PKG/templates/falco-rules/${rule}.yaml
done
```

| Rule File | MITRE Tactics | What It Detects |
|-----------|---------------|-----------------|
| `mitre-mappings.yaml` | Full kill chain (11 tactics) | 15 rules across Initial Access → Impact |
| `crypto-mining.yaml` | Impact (T1496) | Mining binaries, stratum protocol, pool DNS |
| `data-exfiltration.yaml` | Exfiltration (T1048) | Credential theft, data staging, DNS tunnels |
| `privilege-escalation.yaml` | Priv Esc (T1548/T1611) | Setuid, sudo, kernel modules, nsenter |
| `persistence.yaml` | Persistence (T1053/T1098) | Cron jobs, systemd, SSH keys, shell profiles |

---

## Step 5: Client-Specific Exceptions

```bash
cp $PKG/templates/falco-rules/allowlist.yaml \
   ~/GP-copilot/GP-PROJECTS/01-instance/slot-<N>/falco-custom.yaml

# Edit: add client's specific namespaces, images, service accounts
# Apply
bash $PKG/tools/tune-falco.sh \
  --add-allowlist ~/GP-copilot/GP-PROJECTS/01-instance/slot-<N>/falco-custom.yaml
```

---

## Step 6: Verify

```bash
bash $PKG/tools/tune-falco.sh --list-rules
bash $PKG/tools/tune-falco.sh --show-top
```

**Target:** <50 alerts/day after tuning.

---

## Next Steps

- Deploy monitoring → [05-deploy-monitoring.md](05-deploy-monitoring.md)

---

*Ghost Protocol — Runtime Security Package (CKS)*
