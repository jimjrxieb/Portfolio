# Incident Evidence Pattern

## Overview
Immutable forensic evidence with S3 + CloudTrail + MFA Delete + Object Lock.

## Flashcard Mapping
**Goal:** Incident evidence
**Practice:** Archive Flow Logs with SHA256 hash
**Tool:** S3 Glacier, Object Lock

## Architecture
- S3 Glacier for long-term log retention
- S3 Object Lock for immutability
- MFA Delete for protection against deletion
- SHA256 integrity verification
- CloudTrail logs with file validation

## Compliance
- PCI-DSS: 10.5.3 - Protect audit trail files
- FedRAMP: AU-9 - Protection of Audit Information
- HIPAA: 164.312(b) - Audit controls

## Cost
~$5/month (S3 Glacier storage for 10GB/month)
