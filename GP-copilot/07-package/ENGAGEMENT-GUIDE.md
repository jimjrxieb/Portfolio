# FedRAMP-Ready Engagement Guide

> Scan, assess, and document a client's path from zero compliance to ATO-ready.
> This package orchestrates all scanners, maps findings to NIST 800-53, and generates
> the POA&M and SSP documentation a 3PAO needs to see.

---

## What This Package Does

```
┌─────────────────────────────────────────────────────────────────────┐
│                   FEDRAMP ENGAGEMENT FLOW                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  run-fedramp-scan.sh                                                 │
│  └─ scan-and-map.py       trivy + semgrep + gitleaks → NIST map     │
│  └─ checkov               IaC scan (Terraform / K8s YAML)           │
│  └─ conftest              K8s manifest policy check                  │
│  └─ trivy image           Container CVEs (RA-5 evidence)            │
│  └─ run-cluster-audit.sh  Live cluster audit (optional, --cluster)  │
│                                                                      │
│  gap-analysis.py                                                     │
│  └─ reads evidence/scan-reports/                                     │
│  └─ maps findings → 27 FedRAMP Moderate controls                    │
│  └─ outputs: control-matrix.md + poam.md + remediation-plan.md     │
│                                                                      │
│  compliance-templates/                                               │
│  └─ ssp-skeleton.md       Fill with evidence paths from above       │
│  └─ poam-template.md      Pre-populated by gap-analysis.py          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Relationship to other packages:**
- **01-APP-SEC** — clean code before this starts
- **03-DEPLOY-RUNTIME** — deploy Falco + jsa-infrasec after this confirms gaps
- **02-CLUSTER-HARDENING** — harden the cluster based on gaps identified here
- **07-FEDRAMP-READY** — the assessment layer that tells you what to fix

---

## Prerequisites

- `trivy`, `semgrep`, `gitleaks` installed (scan-and-map.py calls all three)
- `checkov` installed (`pip install checkov`)
- `kubectl` configured if using `--cluster`
- Client repo checked out locally
- GP-Copilot cloned at `~/linkops-industries/GP-copilot/`

---

## Phase 1: Initial Gap Scan (Day 1)

**Goal:** One command that runs all scanners and produces a gap analysis report.

### Step 1 — Run the full scan

```bash
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/07-FEDRAMP-READY/tools/run-fedramp-scan.sh \
  --client-name "NovaSec Cloud" \
  --target-dir ~/linkops-industries/GP-copilot/GP-PROJECTS/01-instance/slot-3/Anthra-FedRAMP
```

With live cluster audit:

```bash
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/07-FEDRAMP-READY/tools/run-fedramp-scan.sh \
  --client-name "NovaSec Cloud" \
  --target-dir ~/linkops-industries/GP-copilot/GP-PROJECTS/01-instance/slot-3/Anthra-FedRAMP \
  --cluster
```

Custom output directory:

```bash
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/07-FEDRAMP-READY/tools/run-fedramp-scan.sh \
  --client-name "NovaSec Cloud" \
  --target-dir ~/linkops-industries/GP-copilot/GP-PROJECTS/01-instance/slot-3/Anthra-FedRAMP \
  --output-dir ~/engagement-novasec/evidence-2026-02-25
```

Preview without running:

```bash
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/07-FEDRAMP-READY/tools/run-fedramp-scan.sh \
  --client-name "NovaSec Cloud" \
  --target-dir ~/linkops-industries/GP-copilot/GP-PROJECTS/01-instance/slot-3/Anthra-FedRAMP \
  --dry-run
```

### Step 2 — Read the gap analysis output

```bash
# The scan creates this structure:
# evidence-2026-02-25/
# ├── scan-reports/          ← raw scanner output
# │   ├── trivy-results.json
# │   ├── semgrep-results.json
# │   ├── gitleaks-results.json
# │   ├── nist-mapping-report.json
# │   ├── checkov-results.json
# │   └── cluster-audit.md   (if --cluster was used)
# └── gap-analysis/          ← what to act on
#     ├── control-matrix.md  ← START HERE
#     ├── poam.md
#     └── remediation-plan.md

cat evidence-2026-02-25/gap-analysis/control-matrix.md
```

### What the control matrix tells you

```
Control | Family | Status  | Evidence Confirmed              | Priority
--------|--------|---------|-------------------------------|----------
AC-2    | AC     | PARTIAL | rbac_audit                    | P1
AU-2    | AU     | MISSING | none                          | P1
CM-6    | CM     | PARTIAL | checkov, conftest             | P1
IA-5    | IA     | PARTIAL | gitleaks (14 findings, B-rank)| P1
SC-7    | SC     | MISSING | none                          | P1
```

- **MET** — evidence confirmed by scanner, control is covered
- **PARTIAL** — some evidence but gaps remain (most common starting state)
- **MISSING** — no evidence, needs full implementation
- **MANUAL** — cannot be assessed by scanner (requires SSP docs, pen test, etc.)

### Example first-run output (baseline)

On a typical client repo from scratch:
```
Controls assessed: 27
  MET:     0   (0%)
  PARTIAL: 11  (41%)
  MISSING: 15  (56%)
  MANUAL:  1   (4%)

Coverage: 42.3%
```

This is normal. The goal is to get to 80%+ before 3PAO assessment.

### Tested example: Anthra-FedRAMP (Feb 2026)

After applying 01-APP-SEC + 02-CLUSTER-HARDENING + 03-DEPLOY-RUNTIME Falco:
```
Controls assessed: 27
  MET:     5   (19%)
  PARTIAL: 18  (67%)
  MISSING: 3   (11%)
  MANUAL:  1   (4%)

Coverage: 88.5%

Remaining MISSING: AU-3 (audit logging), IR-4 (incident response), SI-4 (monitoring)
→ These close when Falco + jsa-infrasec are running with data collection.
```

---

## Phase 2: Fix High-Priority Gaps (Week 1-3)

**Goal:** Work through `remediation-plan.md` top to bottom. B-rank first, then C, then D.

```bash
cat evidence-2026-02-25/gap-analysis/remediation-plan.md
```

### Iron Legion rank → action

| Rank | Action | Who |
|------|--------|-----|
| **B** | Fix manually, document in SSP | Human |
| **C** | JADE proposes fix, you approve | Human + JADE |
| **D** | jsa-infrasec auto-fixes + logs | Automated |
| **E** | jsa-infrasec auto-fixes silently | Automated |

### AC-2 — RBAC hardening (most common gap)

```bash
# Check current state
kubectl get clusterrolebindings -o wide | grep -v "system:"
kubectl get rolebindings -A | grep -v "system:"

# Apply least-privilege RBAC template
kubectl apply -f ~/linkops-industries/GP-copilot/GP-CONSULTING/07-FEDRAMP-READY/kubernetes-templates/rbac.yaml

# Verify
kubectl auth can-i --list --as <service-account> -n <namespace>
```

### SC-7 — NetworkPolicy (usually MISSING on day 1)

```bash
# Check which namespaces have NetworkPolicy
kubectl get networkpolicy -A

# Apply default-deny template, then add per-namespace allow rules
kubectl apply -f ~/linkops-industries/GP-copilot/GP-CONSULTING/07-FEDRAMP-READY/kubernetes-templates/networkpolicy.yaml

# Verify traffic is blocked by default
kubectl exec -n <ns> <pod> -- wget -q --timeout=3 http://10.0.0.1/
```

### CM-6 — Admission control (Kyverno / Gatekeeper)

Use **02-CLUSTER-HARDENING** to deploy:

```bash
# Kyverno policies
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/admission/deploy-policies.sh \
  --engine kyverno --mode audit

# After verification, switch to enforce mode
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/tools/admission/deploy-policies.sh \
  --engine kyverno --mode enforce
```

### AU-2 / AU-12 — Audit logging

```bash
# Apply audit policy template
kubectl apply -f ~/linkops-industries/GP-copilot/GP-CONSULTING/07-FEDRAMP-READY/remediation-templates/audit-logging.yaml

# Verify audit logs are being written
kubectl logs -n kube-system kube-apiserver-<node> | grep audit | head -5

# Deploy Falco for runtime audit (03-DEPLOY-RUNTIME package)
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME/tools/deploy.sh
```

### IA-5 — Secrets / credential findings

```bash
# gitleaks findings in scan-and-map.py output are B-rank — human review required
cat evidence-2026-02-25/scan-reports/gitleaks-results.json | \
  python3 -c "import json,sys; [print(f['File'], f.get('Match','')) for f in json.load(sys.stdin).get('Leaks',[])]"

# For each finding: rotate the credential, update the secret store
# Document each remediation in the POA&M
```

---

## Phase 3: Re-scan to Close Gaps (Week 3-4)

**Goal:** Run the scan again and confirm control status has improved.

```bash
# Re-scan with new output dir
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/07-FEDRAMP-READY/tools/run-fedramp-scan.sh \
  --client-name "NovaSec Cloud" \
  --target-dir ~/linkops-industries/GP-copilot/GP-PROJECTS/01-instance/slot-3/Anthra-FedRAMP \
  --output-dir ~/engagement-novasec/evidence-2026-03-15

# Compare gap analysis outputs
diff \
  ~/engagement-novasec/evidence-2026-02-25/gap-analysis/control-matrix.md \
  ~/engagement-novasec/evidence-2026-03-15/gap-analysis/control-matrix.md
```

Target trajectory:
```
Week 1 (baseline):  42%  coverage
Week 3 (mid-point): 65%  coverage
Week 6 (pre-3PAO):  80%+ coverage
```

Controls that stay MANUAL (can't automate — need policy/process docs):
- IR-4 (Incident Response Plan)
- SA-9 (Third-party service inventory)
- CP-9 (Backup procedures)

---

## Phase 4: Documentation (Week 4-6)

**Goal:** Produce SSP, control families, and POA&M for the 3PAO.

### SSP skeleton

```bash
# Start from the template
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/07-FEDRAMP-READY/compliance-templates/ssp-skeleton.md \
   ~/engagement-novasec/NovaSec-SSP.md

# Fill in sections:
# - System description (what NovaSec does, who uses it)
# - Authorization boundary (which components are in scope)
# - Control implementation statements (how each control is met)
# - Reference evidence paths from evidence-*/gap-analysis/control-matrix.md
```

Key sections of the SSP to fill in order:
1. **1.0 System Overview** — what the system does, data sensitivity (Moderate)
2. **9.0 Control Families** — one section per family (AC, AU, CM, IA, SC, SI...)
3. **Appendix A** — ports/protocols/services
4. **Appendix B** — FIPS 140-2 validated modules
5. **Appendix C** — cryptographic modules

### POA&M — pre-populated by gap-analysis.py

```bash
# Already generated — just add target dates and responsible parties
cat ~/engagement-novasec/evidence-2026-02-25/gap-analysis/poam.md

# Export to OSCAL format if required
# (jsa-secops handles OSCAL generation for NovaSec)
ls ~/linkops-industries/GP-copilot/GP-PROJECTS/01-instance/slot-3/Anthra-FedRAMP/oscal/
```

The POA&M format matches FedRAMP PMO's template:
- POA&M ID, control, weakness description, scheduled completion, status

### Control families

```bash
cp -r ~/linkops-industries/GP-copilot/GP-CONSULTING/07-FEDRAMP-READY/compliance-templates/control-families/ \
      ~/engagement-novasec/control-families/

# For each family, fill in the "Implementation" section:
# - What tool/policy/config implements it
# - Where the evidence is (path to scan report or K8s manifest)
# - Who is responsible (system owner, cloud provider, shared)
```

---

## Phase 5: 3PAO Prep (Week 8-10)

**Goal:** Evidence package is clean, CI/CD generates fresh evidence automatically, no open B/S findings.

### Wire the CI/CD pipeline

```bash
# Copy the FedRAMP GHA workflow to the client repo
cp ~/linkops-industries/GP-copilot/GP-CONSULTING/07-FEDRAMP-READY/ci-templates/full-security-pipeline.yml \
   ~/linkops-industries/GP-copilot/GP-PROJECTS/01-instance/slot-3/Anthra-FedRAMP/.github/workflows/fedramp-compliance.yml
```

This workflow runs on every push:
- Trivy FS + Semgrep + Gitleaks → uploads to `evidence/`
- scan-and-map.py → generates fresh `nist-mapping-report.json`
- Checkov → IaC scan evidence

### Audit readiness checklist

```bash
# Run final gap scan
bash ~/linkops-industries/GP-copilot/GP-CONSULTING/07-FEDRAMP-READY/tools/run-fedramp-scan.sh \
  --client-name "NovaSec Cloud" \
  --target-dir ~/linkops-industries/GP-copilot/GP-PROJECTS/01-instance/slot-3/Anthra-FedRAMP \
  --cluster

# Confirm:
grep "^| " evidence-*/gap-analysis/control-matrix.md | grep -c "MET"
# Target: 22+ out of 27 controls MET or PARTIAL
# Zero B/S rank findings open in POA&M
```

Pre-3PAO checklist:
- [ ] Coverage 80%+ in control-matrix.md
- [ ] All B-rank findings remediated or formally accepted with risk owner
- [ ] POA&M has target dates and responsible parties filled in
- [ ] SSP has implementation statement for every in-scope control
- [ ] CI/CD pipeline generating fresh evidence on every commit
- [ ] Scan results < 30 days old
- [ ] No privileged container pods in production namespace
- [ ] Default-deny NetworkPolicy in all production namespaces
- [ ] RBAC audit shows no wildcard permissions for non-system accounts

---

## Quick Reference — All Commands

```bash
PKG=~/linkops-industries/GP-copilot/GP-CONSULTING/07-FEDRAMP-READY
TARGET=~/linkops-industries/GP-copilot/GP-PROJECTS/01-instance/slot-3/Anthra-FedRAMP

# Full scan + gap analysis (no cluster)
bash $PKG/tools/run-fedramp-scan.sh \
  --client-name "NovaSec Cloud" \
  --target-dir $TARGET

# With live cluster audit
bash $PKG/tools/run-fedramp-scan.sh \
  --client-name "NovaSec Cloud" \
  --target-dir $TARGET \
  --cluster

# Dry run (preview what would run)
bash $PKG/tools/run-fedramp-scan.sh \
  --client-name "NovaSec Cloud" \
  --target-dir $TARGET \
  --dry-run

# Gap analysis only (re-run after fixes, no re-scanning)
python3 $PKG/tools/gap-analysis.py \
  --client-name "NovaSec Cloud" \
  --scan-dir evidence-2026-02-25/scan-reports \
  --output-dir evidence-2026-02-25/gap-analysis

# Read results
cat evidence-*/gap-analysis/control-matrix.md
cat evidence-*/gap-analysis/poam.md
cat evidence-*/gap-analysis/remediation-plan.md
```

---

## Evidence Folder Structure

After a full scan run:

```
evidence-2026-02-25/
├── scan-reports/
│   ├── trivy-results.json             ← CVEs (RA-5, SI-2)
│   ├── semgrep-results.json           ← SAST findings (SA-11)
│   ├── gitleaks-results.json          ← Secrets (IA-5)
│   ├── nist-mapping-report.json       ← All findings → NIST mapped
│   ├── checkov-results.json           ← IaC misconfigs (CM-6, CM-7)
│   ├── conftest-manifests.txt         ← K8s policy violations (CM-6)
│   └── cluster-audit.md              ← Live cluster (if --cluster)
└── gap-analysis/
    ├── control-matrix.md              ← START HERE (27 controls, MET/PARTIAL/MISSING)
    ├── poam.md                        ← Pre-populated POA&M for 3PAO
    └── remediation-plan.md           ← Ordered by Iron Legion rank
```

---

*GP-Consulting — FedRAMP-Ready Package*
