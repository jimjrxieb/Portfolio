# Vendor Integration (External Detection Sources)

> **"Ingest it. Normalize it. Rank it. Fix it."**
>
> Universal Adapter Layer for Third-Party Security Platforms

---

## How 08-VENDOR-INTEGRATION Saves Money

Companies spend **$50-500K/year** on security platforms like CrowdStrike Falcon, Wiz, or Prisma Cloud. They pay for detection — but detections without action are just noise. The findings pile up in a dashboard nobody has time to triage. That's money spent on alerts, not outcomes.

This package turns vendor spend into vendor ROI:

| What 08-VENDOR-INTEGRATION Does | Cost Impact |
|---------------------------------|-------------|
| **Normalize vendor findings into GP-Copilot schema** | No second triage tool — vendor findings flow into the same rank system as internal scanners |
| **Cross-source deduplication** | Falcon + Trivy find the same CVE = 1 finding, not 2. Eliminates duplicate remediation effort |
| **Auto-remediate vendor findings (E/D rank)** | Findings from $200K/year Falcon license get fixed autonomously — vendor ROI realized |
| **Writeback status to vendor platform** | Vendor dashboard shows remediated, not just detected — compliance evidence without manual updates |
| **Single pane of glass** | Engineers learn one workflow, not one per vendor. Training cost and context switching eliminated |

**Bottom line:** Most companies get 20-30% of the value from their security vendor spend because nobody acts on the findings. This package closes that gap — vendor detections become autonomous remediations. The $200K Falcon license finally pays for itself because JSA fixes what Falcon finds.

---

## The Value Proposition

Your clients already run CrowdStrike Falcon, Wiz, Prisma Cloud, or Aqua. They paid for detection — but detections without action are just noise.

**08-VENDOR-INTEGRATION** bridges that gap. It ingests findings from any vendor platform, normalizes them into GP-Copilot's universal schema, deduplicates against your own scanners, and feeds them into the rank system for autonomous remediation.

```
┌─────────────────────────────────────────────────────────────────┐
│               VENDOR INTEGRATION LAYER                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   INGEST              NORMALIZE            ROUTE                │
│      │                    │                    │                 │
│      ▼                    ▼                    ▼                 │
│  ┌─────────┐        ┌─────────┐         ┌─────────┐            │
│  │ Vendor  │───────▶│ Shared  │────────▶│  Rank   │            │
│  │ Adapter │        │ Schema  │         │ System  │            │
│  │ (API)   │        │ + Dedup │         │ E→D→C   │            │
│  └─────────┘        └─────────┘         └─────────┘            │
│       │                                       │                  │
│       ▼                                       ▼                  │
│  ┌─────────┐                            ┌─────────┐            │
│  │Writeback│                            │ Auto-   │            │
│  │ Status  │◀───────────────────────────│ Remedy  │            │
│  └─────────┘                            └─────────┘            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key differentiator**: RankClassifier doesn't know or care if the finding came from Falcon, Wiz, or Trivy. The adapter normalizes it; the platform handles it.

---

## Adapter Architecture

Each vendor adapter follows the same pattern:

```
vendor-adapter/
├── ingester.py        ← Poll or receive findings from vendor API
├── mapper.py          ← Transform vendor schema → GP universal schema
├── config.yaml        ← API credentials, poll intervals, severity mappings
└── README.md          ← Vendor-specific setup instructions
```

All adapters share:

```
shared/
├── normalizer.py      ← Common finding schema (GPFinding dataclass)
├── deduplicator.py    ← Cross-source dedup (Falcon + Trivy finding = 1 finding)
├── writeback.py       ← Update vendor platform with remediation status
└── registry.py        ← Adapter discovery and lifecycle management
```

---

## Supported Adapters

| Adapter | Vendor | Status | Ingestion Method |
|---------|--------|--------|-----------------|
| `falcon/` | CrowdStrike Falcon | **Active** | OAuth2 API polling |
| `wiz/` | Wiz | Planned | GraphQL API |
| `prisma/` | Palo Alto Prisma Cloud | Planned | REST API |
| `aqua/` | Aqua Security | Planned | REST API |

---

## Quick Start (Falcon)

### 1. Configure credentials

```bash
cp 08-VENDOR-INTEGRATION/falcon/config.example.yaml \
   08-VENDOR-INTEGRATION/falcon/config.yaml

# Edit config.yaml with your Falcon API credentials
# NEVER commit config.yaml — it's in .gitignore
```

### 2. Test connectivity

```bash
bash 08-VENDOR-INTEGRATION/tools/test-connection.sh --adapter falcon
```

### 3. Run initial ingestion

```bash
bash 08-VENDOR-INTEGRATION/tools/ingest.sh --adapter falcon --mode poll
```

### 4. View normalized findings

```bash
bash 08-VENDOR-INTEGRATION/tools/list-findings.sh --source falcon --format table
```

---

## How It Fits

```
01-APP-SEC ──────────┐
02-CLUSTER-HARDENING ├── GP-Copilot's own scanners (what we find)
03-DEPLOY-RUNTIME ───┘
                          ↕ dedup
08-VENDOR-INTEGRATION ── External scanners (what they find)
                          ↓
04-JSA-AUTONOMOUS ─────── Autonomous remediation (E/D rank)
05-JADE-SRE ───────────── AI supervision (C rank decisions)
```

A finding from Falcon and a finding from Trivy about the same CVE on the same image = **one finding**, not two. The deduplicator handles this.

---

## Relationship to Other Packages

| Package | Relationship |
|---------|-------------|
| `01-APP-SEC` | Dedup: Falcon container vuln vs Trivy SCA finding |
| `02-CLUSTER-HARDENING` | Dedup: Falcon K8s misconfiguration vs Kubescape finding |
| `03-DEPLOY-RUNTIME` | Dedup: Falcon runtime alert vs Falco alert |
| `04-JSA-AUTONOMOUS` | JSA agents consume normalized findings regardless of source |
| `05-JADE-SRE` | JADE sees vendor findings alongside internal findings |
| `07-FEDRAMP-READY` | Vendor findings feed into compliance evidence collection |
