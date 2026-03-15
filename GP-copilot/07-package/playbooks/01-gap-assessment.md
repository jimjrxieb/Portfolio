# Playbook 01: FedRAMP Gap Assessment

> Derived from [GP-CONSULTING/07-FEDRAMP-READY/playbooks/00-fedramp-quickstart.md + 05-system-integrity.md](https://github.com/jimjrxieb/GP-copilot)
> Tailored for the Portfolio application (linksmlm.com)

## What This Does

Runs automated scanners against the Portfolio codebase and infrastructure, maps every finding to a NIST 800-53 control, and generates a control matrix showing exactly where you stand against FedRAMP Moderate (323 controls, 27 priority).

## The 27 Priority Controls

GP-CONSULTING focuses on 27 controls across 10 NIST families that are automatable and produce measurable evidence:

| Family | Controls | What They Cover |
|--------|----------|----------------|
| **AC** (Access Control) | AC-2, AC-3, AC-6, AC-17 | RBAC, least privilege, remote access |
| **AU** (Audit) | AU-2, AU-3, AU-6, AU-12 | What to log, log format, log review |
| **CA** (Assessment) | CA-2, CA-7 | Security assessments, continuous monitoring |
| **CM** (Configuration) | CM-2, CM-6, CM-7, CM-8 | Baselines, secure config, least functionality, inventory |
| **IA** (Identity) | IA-2, IA-5 | User identification, secret management |
| **IR** (Incident Response) | IR-4, IR-5 | Incident handling, monitoring |
| **RA** (Risk) | RA-5, RA-7 | Vulnerability scanning, risk tracking |
| **SA** (Acquisition) | SA-3, SA-11 | SDLC, developer testing |
| **SC** (System/Comms) | SC-7, SC-8, SC-12, SC-28 | Network segmentation, TLS, encryption |
| **SI** (Integrity) | SI-2, SI-4, SI-10 | Patching, monitoring, input validation |

## How the Scan Works

```
run-fedramp-scan.sh
  ├── Trivy FS (dependency CVEs)         → trivy-results.json
  ├── Semgrep SAST (code vulnerabilities) → semgrep-results.json
  ├── Gitleaks (hardcoded secrets)        → gitleaks-results.json
  ├── Checkov (IaC misconfigurations)     → checkov-results.json
  ├── Conftest (K8s policy violations)    → conftest-results.txt
  └── Trivy image (container CVEs)        → trivy-image-results.json
       ↓
  scan-and-map.py
  (maps each finding to NIST 800-53 control + assigns E/D/C/B/S rank)
       ↓
  gap-analysis.py
  (generates 3 output files)
       ↓
  ├── control-matrix.md   ← START HERE: MET/PARTIAL/MISSING/MANUAL per control
  ├── poam.md             ← Plan of Action & Milestones (open findings)
  └── remediation-plan.md ← Prioritized fix list by rank
```

## What a Typical First Scan Shows

| Status | Controls | Percentage | What It Means |
|--------|----------|-----------|---------------|
| **MET** | 8-12 | 30-45% | Evidence confirms the control is implemented |
| **PARTIAL** | 5-8 | 19-30% | Some evidence but gaps remain |
| **MISSING** | 7-12 | 26-44% | No evidence of implementation |
| **MANUAL** | 2-4 | 7-15% | Requires human documentation (e.g., IR plan) |

## Portfolio's Expected Baseline

Portfolio already has significant security posture from 01-APP-SEC and 02-CLUSTER-HARDENING:

| Control | Expected Status | Why |
|---------|----------------|-----|
| AC-6 (Least Privilege) | MET | Non-root containers, RBAC scoped, Gatekeeper enforcing |
| CM-6 (Secure Config) | MET | Kyverno/Gatekeeper policies, PSS restricted |
| RA-5 (Vuln Scanning) | MET | 8-scanner CI pipeline |
| SC-7 (Boundary Protection) | MET | NetworkPolicy default-deny + explicit allows |
| SI-2 (Flaw Remediation) | PARTIAL | CVE scanning in CI, but no SLA on fix timelines |
| AU-2 (Audit Events) | PARTIAL | K8s audit exists but not centralized |
| IR-4 (Incident Handling) | MISSING | No formal incident response plan |
| SC-8 (Transmission Confidentiality) | PARTIAL | TLS on ingress, but no mTLS between pods |

## What Happens Next

1. **Read control-matrix.md** — understand current coverage
2. **Playbook 02** — remediate MISSING and PARTIAL controls
3. **Playbook 03** — generate documentation (SSP, POA&M, SAR)
4. **Re-scan** — prove improvement with before/after comparison
