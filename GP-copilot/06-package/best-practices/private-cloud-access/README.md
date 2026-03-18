# Private Cloud Access Pattern

## Overview
Access AWS services (S3, DynamoDB, etc.) via VPC Endpoints - no internet egress required.

## Flashcard Mapping
**Goal:** Private AWS access
**Practice:** S3/DynamoDB via VPC Endpoint
**Tool:** VPC Endpoints

## Architecture
- VPC Endpoints for S3, DynamoDB, Secrets Manager, etc.
- No internet gateway or NAT gateway needed
- Traffic stays within AWS network

## Compliance
- HIPAA: 164.312(e)(1) - Transmission Security
- FedRAMP: AC-4 - Information Flow Enforcement
- CIS: 5.5 - VPC Endpoint Usage

## Cost
~$7/month per interface endpoint
Gateway endpoints (S3, DynamoDB) are free
