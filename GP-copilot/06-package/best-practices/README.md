# Cloud Security Patterns Library

## Overview
Production-ready security patterns for AWS cloud architecture. Each pattern includes Terraform templates, OPA enforcement policies, and compliance mappings.

## Available Patterns

### 1. [VPC Isolation](vpc-isolation/)
**Flashcard:** Multi-AZ VPC with public/private subnets
**Use Case:** Isolate workloads from internet, minimize attack surface
**Compliance:** CIS 5.1-5.4, PCI-DSS 1.2.1, HIPAA 164.312(e)(1)
**Cost:** ~$160/month

### 2. [Zero-Trust Security Groups](zero-trust-sg/)
**Flashcard:** SG referencing SG (no 0.0.0.0/0)
**Use Case:** Implement least-privilege network access
**Compliance:** CIS 5.2, 5.3, PCI-DSS 1.2.1
**Cost:** Free

### 3. [Private Cloud Access](private-cloud-access/)
**Flashcard:** S3/DynamoDB via VPC Endpoint
**Use Case:** Access AWS services without internet egress
**Compliance:** HIPAA 164.312(e)(1), FedRAMP AC-4
**Cost:** ~$7/month per endpoint

### 4. [Centralized Egress](centralized-egress/)
**Flashcard:** NAT Gateway + Egress Firewall
**Use Case:** Control and inspect all outbound traffic
**Compliance:** PCI-DSS 1.3.4, FedRAMP SC-7
**Cost:** ~$350/month

### 5. [DDoS Resilience](ddos-resilience/)
**Flashcard:** CloudFront + Shield Advanced
**Use Case:** Protect against volumetric DDoS attacks
**Compliance:** NIST CSF PR.PT-5
**Cost:** ~$3,000/month (Shield Advanced)

### 6. [Visibility & Monitoring](visibility-monitoring/)
**Flashcard:** VPC Flow Logs + GuardDuty
**Use Case:** Real-time threat detection and incident response
**Compliance:** CIS 3.9, PCI-DSS 10.1, FedRAMP AU-2
**Cost:** ~$250/month

### 7. [Incident Evidence](incident-evidence/)
**Flashcard:** Archive Flow Logs with SHA256 hash
**Use Case:** Immutable forensic evidence for investigations
**Compliance:** PCI-DSS 10.5.3, FedRAMP AU-9
**Cost:** ~$5/month (S3 Glacier)

## Usage

```bash
# Deploy a pattern
cd vpc-isolation/
terraform init
terraform apply -var="project_name=myproject"

# Validate with OPA
conftest test . -p opa-policy.rego

# Scan with SecOps framework
cd ../../secops-framework/
./run-secops.sh
```

## Pattern Selection Guide

| Industry | Recommended Patterns | Rationale |
|----------|---------------------|------------|
| **Financial Services** | VPC Isolation + Zero-Trust SG + Visibility | PCI-DSS requires network segmentation and logging |
| **Healthcare** | VPC Isolation + Private Cloud Access + Incident Evidence | HIPAA requires PHI isolation and audit trails |
| **Defense/Government** | All 7 patterns | FedRAMP/NIST 800-53 requires defense-in-depth |
| **SaaS Startups** | VPC Isolation + Zero-Trust SG | Cost-effective baseline security |
| **E-commerce** | VPC Isolation + DDoS Resilience + Visibility | Protect against attacks, monitor transactions |

## Compliance Matrix

| Pattern | CIS | PCI-DSS | HIPAA | FedRAMP | SOC2 |
|---------|-----|---------|-------|---------|------|
| VPC Isolation | ✅ 5.1-5.4, 3.9 | ✅ 1.2.1, 10.1 | ✅ 164.312(e)(1) | ✅ AC-4, SC-7 | ✅ CC6.1 |
| Zero-Trust SG | ✅ 5.2, 5.3 | ✅ 1.2.1 | ✅ 164.312(a)(1) | ✅ AC-3, AC-4 | ✅ CC6.1 |
| Private Cloud Access | ✅ 5.5 | ✅ 1.3.4 | ✅ 164.312(e)(1) | ✅ AC-4 | ✅ CC6.6 |
| Centralized Egress | ✅ 5.1 | ✅ 1.3.4 | ⚠️ Addressable | ✅ SC-7 | ✅ CC6.6 |
| DDoS Resilience | ✅ 3.1 | ⚠️ Recommended | ⚠️ Addressable | ✅ SC-5 | ✅ A1.2 |
| Visibility | ✅ 3.9, 3.2 | ✅ 10.1-10.7 | ✅ 164.308(a)(1) | ✅ AU-2, AU-6 | ✅ CC7.2 |
| Incident Evidence | ✅ 3.9 | ✅ 10.5.3 | ✅ 164.308(a)(1) | ✅ AU-9 | ✅ CC7.3 |

## Contributing

To add a new pattern:
1. Create directory: `cloud-security-patterns/my-pattern/`
2. Add files: `terraform-template.tf`, `opa-policy.rego`, `compliance-mapping.md`, `README.md`
3. Test: `terraform validate && opa test . && conftest test .`
4. Update this README with pattern details

## Support

For questions or issues:
- Documentation: See individual pattern READMEs
- Issues: Open GitHub issue
- Compliance questions: See `compliance-mapping.md` in each pattern
