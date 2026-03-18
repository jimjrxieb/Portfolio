# Visibility & Monitoring Pattern

## Overview
Real-time threat detection with VPC Flow Logs + GuardDuty + CloudWatch.

## Flashcard Mapping
**Goal:** Visibility
**Practice:** Enable VPC Flow Logs + GuardDuty
**Tool:** CloudWatch, GuardDuty

## Architecture
- VPC Flow Logs capture all network traffic
- CloudWatch Logs for real-time analysis
- GuardDuty for threat detection
- CloudTrail for API audit logging

## Compliance
- CIS: 3.9, 3.2 - Flow Logs and CloudTrail
- PCI-DSS: 10.1-10.7 - Audit trails
- FedRAMP: AU-2, AU-6 - Audit and monitoring
- HIPAA: 164.308(a)(1)(ii)(D) - Activity review

## Cost
~$250/month (Flow Logs + GuardDuty)
