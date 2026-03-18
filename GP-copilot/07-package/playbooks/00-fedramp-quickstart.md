# FedRAMP Quickstart — Any Application
### From Zero to ATO-Ready

This playbook gets any application through FedRAMP compliance. Not theoretical — step by step.

---

## WHO THIS IS FOR

You have an application. A client (or your own org) needs FedRAMP authorization. You need to know exactly what to do, in what order, and what "done" looks like at each stage.

---

## THE 5 PHASES

```
Phase 1: Gap Assessment (Day 1)          → "Where are we?"
Phase 2: Remediate Priority Gaps (Week 1-3) → "Fix what matters first"
Phase 3: Re-scan + Close Gaps (Week 3-4)   → "Prove it's fixed"
Phase 4: Documentation Package (Week 4-6)  → "Write the SSP, POA&M, SAR"
Phase 5: 3PAO Prep (Week 8-10)            → "Get ready for the assessor"
```

**Realistic timeline:** 10-16 weeks for Moderate. 6-8 weeks for Low.

---

## FEDRAMP BASICS — WHAT YOU NEED TO KNOW

### Impact Levels

| Level | Controls | What it protects | Example |
|-------|----------|-----------------|---------|
| **Low** | 125 controls | Public info, low-impact loss | Public website, open data portal |
| **Moderate** | 323 controls | Controlled unclassified, PII | SaaS platforms, HR systems, email |
| **High** | 421 controls | Law enforcement, emergency services | Critical infrastructure, classified-adjacent |

**Most commercial SaaS selling to government = Moderate.**

### The 10 Control Families That Matter Most

| Family | Code | What it covers |
|--------|------|---------------|
| Access Control | AC | Who can access what, RBAC, least privilege |
| Audit & Accountability | AU | Logging, audit trails, evidence |
| Security Assessment | CA | Scanning, vulnerability assessment |
| Configuration Management | CM | Baselines, change control, IaC |
| Identification & Authentication | IA | Secrets, MFA, credential management |
| Incident Response | IR | Detection, alerting, response procedures |
| Risk Assessment | RA | Vulnerability scanning, risk ranking |
| System Acquisition | SA | Secure SDLC, supply chain |
| System & Communications Protection | SC | Encryption, network segmentation, TLS |
| System & Information Integrity | SI | Patching, monitoring, malware defense |

### Our 27 Priority Controls (FedRAMP Moderate)

These are the 27 controls our tooling can assess and partially automate:

```
AC-2   Account Management          AC-3   Access Enforcement
AC-6   Least Privilege             AC-17  Remote Access
AU-2   Audit Events                AU-3   Content of Audit Records
AU-6   Audit Review                AU-12  Audit Generation
CA-2   Security Assessments        CA-7   Continuous Monitoring
CM-2   Baseline Configuration      CM-6   Configuration Settings
CM-7   Least Functionality         CM-8   Component Inventory
IA-2   Identification (Users)      IA-5   Authenticator Management
IR-4   Incident Handling           IR-5   Incident Monitoring
RA-5   Vulnerability Scanning      RA-7   Risk Response
SA-3   System Dev Lifecycle        SA-11  Developer Testing
SC-7   Boundary Protection         SC-8   Transmission Confidentiality
SC-12  Cryptographic Key Mgmt      SC-28  Protection at Rest
SI-2   Flaw Remediation            SI-4   Information System Monitoring
SI-10  Information Input Validation
```

---

## PHASE 1: GAP ASSESSMENT (DAY 1)

### Prerequisites

```bash
# Install scanning tools
pip install semgrep
brew install trivy       # or: apt install trivy
brew install gitleaks    # or: go install github.com/gitleaks/gitleaks/v8@latest
pip install checkov

# Verify
trivy --version && semgrep --version && gitleaks version && checkov --version
```

### Run the full scan

```bash
cd /path/to/client-application

# Run everything — scans code, IaC, containers, maps to NIST controls
/path/to/GP-CONSULTING/07-FEDRAMP-READY/tools/run-fedramp-scan.sh \
  --target . \
  --output ./fedramp-evidence/baseline-$(date +%Y%m%d) \
  --project "clientname-baseline"

# Or dry-run first to see what it will do
/path/to/GP-CONSULTING/07-FEDRAMP-READY/tools/run-fedramp-scan.sh \
  --target . \
  --output ./fedramp-evidence/baseline-$(date +%Y%m%d) \
  --dry-run
```

### What it runs (in order)

1. **scan-and-map.py** — Trivy FS + Semgrep + Gitleaks → NIST mapping
2. **Checkov** — IaC scanning (Terraform, CloudFormation, K8s manifests, Dockerfiles)
3. **Conftest** — K8s manifests against FedRAMP OPA policies
4. **Trivy image scan** — Container image vulnerabilities
5. **Cluster audit** — Live cluster scan (if `--cluster` flag)
6. **gap-analysis.py** — Reads all scan output → generates control matrix, POA&M, remediation plan

### Read the output

```bash
# Your evidence folder now looks like:
fedramp-evidence/baseline-20260311/
├── scan-reports/
│   ├── trivy-fs.json              # Code vulnerabilities
│   ├── semgrep-results.json       # SAST findings
│   ├── gitleaks-report.json       # Hardcoded secrets
│   ├── checkov-results.json       # IaC misconfigurations
│   ├── conftest-results.json      # K8s policy violations
│   ├── trivy-images.json          # Container image CVEs
│   └── nist-mapping-report.json   # Everything mapped to NIST controls
└── gap-analysis/
    ├── control-matrix.md          # ← START HERE: MET/PARTIAL/MISSING per control
    ├── poam.md                    # Pre-populated Plan of Action & Milestones
    └── remediation-plan.md        # Prioritized fix list (B→C→D→E rank)
```

### Interpret the control matrix

Open `control-matrix.md`. Each control shows one of 4 statuses:

| Status | What it means | What to do |
|--------|--------------|------------|
| **MET** | Scanner evidence confirms control is satisfied | Document it. Move on. |
| **PARTIAL** | Some evidence exists but gaps remain | Fix the gaps. Re-scan. |
| **MISSING** | No scanner evidence for this control | Implement from scratch or provide manual evidence |
| **MANUAL** | Cannot be automated — requires human attestation | Write the narrative, collect process evidence |

### Typical first-scan results

```
Week 1 baseline (before any fixes):
  MET:     8-12 controls (30-45%)
  PARTIAL: 5-8 controls
  MISSING: 7-12 controls
  MANUAL:  2-4 controls

This is normal. Don't panic.
```

### What to do next

1. Read `remediation-plan.md` — it's ordered by priority (B-rank first, then C, D, E)
2. Go to Phase 2 for each control family that needs work
3. Use the specific playbooks for each area:
   - Access control gaps → `01-access-control-hardening.md`
   - Audit/logging gaps → `02-audit-logging.md`
   - Config management gaps → `03-configuration-management.md`
   - Encryption/network gaps → `04-system-communications.md`
   - Vulnerability gaps → `05-system-integrity.md`
   - Secrets/auth gaps → `06-identity-authentication.md`
   - Incident response gaps → `07-incident-response.md`

---

## PHASE 2: REMEDIATE (WEEK 1-3)

### Priority order (fix these first)

```
Priority 1 (Week 1): B-rank findings — human-decides, highest risk
  → SC-7  (network segmentation — if flat network, fix NOW)
  → AC-6  (least privilege — if running as root, fix NOW)
  → IA-5  (secrets management — if hardcoded secrets, fix NOW)

Priority 2 (Week 2): C-rank findings — significant but automatable
  → CM-6  (admission control — deploy Kyverno/Gatekeeper)
  → AU-2  (audit logging — enable K8s audit + CloudTrail)
  → SI-2  (vulnerability patching — fix critical CVEs)

Priority 3 (Week 3): D/E-rank findings — pattern fixes
  → AC-2  (RBAC configuration)
  → SC-28 (encryption at rest)
  → CM-2  (baseline configuration)
```

Each playbook in this folder covers the specific steps. See table of contents below.

---

## PHASE 3: RE-SCAN (WEEK 3-4)

```bash
# Run the same scan against the fixed codebase
/path/to/GP-CONSULTING/07-FEDRAMP-READY/tools/run-fedramp-scan.sh \
  --target . \
  --output ./fedramp-evidence/post-fix-$(date +%Y%m%d) \
  --project "clientname-postfix"
```

### Expected trajectory

```
Week 1 baseline:    42% coverage (8/27 MET or PARTIAL)
Week 3 post-fix:    65% coverage (17/27 MET or PARTIAL)
Week 6 final:       80%+ coverage (22+/27 MET or PARTIAL)
```

The remaining 15-20% are MANUAL controls — you can't automate them, you document them.

---

## PHASE 4: DOCUMENTATION (WEEK 4-6)

See `08-documentation-package.md` for full details. The deliverables:

| Document | Template location | What it is |
|----------|------------------|------------|
| System Security Plan (SSP) | `templates/compliance-templates/ssp-skeleton.md` | Master document describing the system and all controls |
| Plan of Action & Milestones (POA&M) | Generated by `gap-analysis.py` | Tracking document for unfixed findings |
| Security Assessment Report (SAR) | `templates/compliance-templates/sar-template.md` | Results of security assessment |
| Control Matrix | Generated by `gap-analysis.py` | Status of each control |
| Control Family Narratives | `templates/compliance-templates/control-families/` | Per-family implementation descriptions |

---

## PHASE 5: 3PAO PREP (WEEK 8-10)

See `09-3pao-prep.md` for full details. The checklist:

```
[ ] Control matrix shows 80%+ MET/PARTIAL
[ ] Zero B-rank or S-rank findings open
[ ] POA&M has realistic timelines for remaining gaps
[ ] SSP is complete and matches actual implementation
[ ] Evidence is less than 30 days old
[ ] All pods run as non-root with security contexts
[ ] NetworkPolicies exist in every namespace
[ ] RBAC follows least privilege (no wildcard verbs)
[ ] Audit logging covers all control plane operations
[ ] CI/CD pipeline generates fresh evidence on every deploy
[ ] Encryption at rest and in transit verified
[ ] Incident response plan documented and tested
```

---

## PLAYBOOK INDEX

| Playbook | Focus | Controls covered |
|----------|-------|-----------------|
| `00-fedramp-quickstart.md` | This file — overview and phases | All |
| `01-access-control-hardening.md` | RBAC, least privilege, account management | AC-2, AC-3, AC-6, AC-17 |
| `02-audit-logging.md` | Audit trails, log aggregation, evidence collection | AU-2, AU-3, AU-6, AU-12 |
| `03-configuration-management.md` | IaC baselines, admission control, inventory | CM-2, CM-6, CM-7, CM-8 |
| `04-system-communications.md` | Encryption, network segmentation, TLS | SC-7, SC-8, SC-12, SC-28 |
| `05-system-integrity.md` | Vulnerability scanning, patching, monitoring | SI-2, SI-4, SI-10, RA-5, RA-7 |
| `06-identity-authentication.md` | Secrets management, MFA, credential lifecycle | IA-2, IA-5 |
| `07-incident-response.md` | Falco, alerting, IR procedures | IR-4, IR-5 |
| `08-documentation-package.md` | SSP, POA&M, SAR, control narratives | CA-2, CA-7, SA-3, SA-11 |
| `09-3pao-prep.md` | Assessment readiness, evidence freshness | All |
| `10-continuous-compliance.md` | CI/CD evidence pipeline, ongoing monitoring | CA-7, SI-4 |
