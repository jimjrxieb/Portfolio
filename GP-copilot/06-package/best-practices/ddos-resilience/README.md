# DDoS Resilience Pattern

## Overview
Protect against volumetric DDoS attacks with CloudFront + Shield Advanced.

## Flashcard Mapping
**Goal:** DDoS resilience
**Practice:** CloudFront + Shield Advanced
**Tool:** AWS Shield, CloudFront, WAF

## Architecture
- CloudFront distribution for edge caching
- AWS Shield Advanced for DDoS protection
- AWS WAF for application-layer filtering
- Automated DDoS response team (DRT)

## Compliance
- NIST CSF: PR.PT-5 - DDoS protection
- FedRAMP: SC-5 - Denial of Service Protection

## Cost
~$3,000/month (Shield Advanced $3,000 + data transfer)
Standard Shield is free
