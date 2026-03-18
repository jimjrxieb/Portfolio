# Centralized Egress Pattern

## Overview
Control and inspect all outbound traffic with Network Firewall + NAT Gateway.

## Flashcard Mapping
**Goal:** Centralize egress
**Practice:** NAT Gateway + Egress Firewall
**Tool:** AWS Network Firewall

## Architecture
- AWS Network Firewall for deep packet inspection
- URL filtering, domain allowlisting
- Centralized egress through inspection VPC

## Compliance
- PCI-DSS: 1.3.4 - Control outbound traffic
- FedRAMP: SC-7 - Boundary Protection
- NIST: SC-7(5) - Deny by default, allow by exception

## Cost
~$350/month (Network Firewall + NAT Gateway)
