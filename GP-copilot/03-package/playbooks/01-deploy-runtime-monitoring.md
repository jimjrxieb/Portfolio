# Playbook 01: Deploy Runtime Security Monitoring

> Derived from [GP-CONSULTING/03-DEPLOY-RUNTIME/playbooks/02-deploy-falco.md + 04-tune-falco.md](https://github.com/jimjrxieb/GP-copilot)
> Tailored for the Portfolio k3s cluster (portfolioserver)

## What This Does

Deploys Falco as a DaemonSet on the Portfolio cluster to monitor running containers in real time. Falco watches syscalls via eBPF and fires alerts when it detects suspicious activity — cryptomining, privilege escalation, shell spawning, credential theft.

## What Falco Detects

| Category | Detection | MITRE ATT&CK | NIST | Example on Portfolio |
|----------|-----------|-------------|------|---------------------|
| **Privilege Escalation** | setuid, sudo, nsenter, kernel module load | T1548 | AC-6 | Someone `kubectl exec` into API pod and runs `sudo` |
| **Cryptomining** | Mining binaries, stratum protocol, pool DNS | T1496 | SI-2 | Compromised container connects to mining pool |
| **Data Exfiltration** | Credential files read, data staging, DNS tunnels | T1048 | SI-4 | Process reads `/etc/shadow` or K8s service account token |
| **Persistence** | Cron jobs, systemd units, SSH key injection | T1053 | AU-2 | Attacker adds cron job inside container |
| **Container Escape** | Host mount write, namespace manipulation | T1611 | SC-7 | Container writes to host filesystem |
| **K8s API Abuse** | cluster-admin binding, secret access, exec into pod | T1098 | AC-6 | Someone creates a ClusterRoleBinding to cluster-admin |

## Deployment on Portfolio

```
Falco DaemonSet (1 pod on portfolioserver)
  → Monitors syscalls via eBPF
  → JSON alerts to stdout
  → falco-exporter scrapes gRPC → Prometheus metrics
  → Grafana dashboards visualize trends
```

## Tuning Process

Week 1 is observe-only. Baseline typically shows ~500 alerts/day from legitimate activity:

1. **Identify noisy rules**: Monitoring agents, CI runners, init containers trigger false positives
2. **Apply allowlist**: Suppress known-good patterns (Prometheus scraping, ArgoCD syncing)
3. **Load threat rules**: Crypto-mining, data exfiltration, privilege escalation, persistence
4. **Target**: <50 alerts/day after tuning

## Alert Rules (Prometheus)

| Alert | What It Means | Severity |
|-------|--------------|----------|
| FalcoSilent | DaemonSet not running on any node | CRITICAL |
| CriticalMITRETactic | Critical-severity Falco rule fired | CRITICAL |
| FalcoPodNotRunning | Falco pod not ready | HIGH |
| HighAlertRate | >50 alerts/min (attack or misconfiguration) | HIGH |

## What This Means for Portfolio

Before runtime monitoring:
- If someone compromises the API pod, you find out from customer complaints
- No visibility into what containers are actually doing at runtime

After Falco:
- Shell spawn in container → alert in <10 seconds
- Credential theft attempt → alert + forensic capture
- Cryptominer deployed → detected by process name + network connection
