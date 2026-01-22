# VPC Networking Lab: Public/Private Subnet Architecture

**Author**: Jimmie  
**Date**: January 19, 2026  
**Environment**: LocalStack (AWS simulation)  
**Related Role**: Cloud Security Automation Engineer

---

## Objective

Build a VPC architecture with public and private subnet separation, demonstrating understanding of network isolation, routing, and security group configuration.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  VPC: 10.0.0.0/16 (65,536 IPs)                                  │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │  PUBLIC SUBNET: 10.0.1.0/24                             │   │
│   │  - Internet-facing resources                            │   │
│   │  - Route: 0.0.0.0/0 → Internet Gateway                  │   │
│   │  - Security Group: Allow HTTP (port 80)                 │   │
│   └─────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                    Internet Gateway                              │
│                              │                                   │
│                          Internet                                │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │  PRIVATE SUBNET: 10.0.2.0/24                            │   │
│   │  - Internal resources (databases, APIs)                 │   │
│   │  - No direct internet route                             │   │
│   │  - Isolated from external access                        │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Steps

### Step 1: Create the VPC

The VPC is the isolated network boundary. CIDR block `10.0.0.0/16` provides 65,536 available IP addresses.

```bash
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --query 'Vpc.VpcId' --output text
```
**Result**: `vpc-4139dbf71c5d2ee50`

---

### Step 2: Create Public Subnet

Carve out 256 IPs (10.0.1.0 - 10.0.1.255) for internet-facing resources.

```bash
aws ec2 create-subnet \
  --vpc-id vpc-4139dbf71c5d2ee50 \
  --cidr-block 10.0.1.0/24 \
  --query 'Subnet.SubnetId' --output text
```
**Result**: `subnet-a5bc626e84ca06d73`

---

### Step 3: Create Private Subnet

Carve out 256 IPs (10.0.2.0 - 10.0.2.255) for internal resources with no internet access.

```bash
aws ec2 create-subnet \
  --vpc-id vpc-4139dbf71c5d2ee50 \
  --cidr-block 10.0.2.0/24 \
  --query 'Subnet.SubnetId' --output text
```
**Result**: `subnet-b50d3ed87a150ab1f`

---

### Step 4: Create Security Group

Security groups act as virtual firewalls controlling inbound and outbound traffic at the resource level.

```bash
aws ec2 create-security-group \
  --group-name web-sg \
  --description "Allow HTTP" \
  --vpc-id vpc-4139dbf71c5d2ee50
```
**Result**: `sg-094e5e55b28e5a8ec`

---

### Step 5: Configure Security Group Rules

Allow HTTP traffic (port 80) from any source. Note: `0.0.0.0/0` should be reviewed for production use.

```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-094e5e55b28e5a8ec \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```
**Result**: `sgr-fd0833071762686e9`

---

### Step 6: Create Internet Gateway

The Internet Gateway enables communication between the VPC and the internet.

```bash
aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' --output text
```
**Result**: `igw-897f4ecc60e37edd2`

---

### Step 7: Attach Internet Gateway to VPC

```bash
aws ec2 attach-internet-gateway \
  --internet-gateway-id igw-897f4ecc60e37edd2 \
  --vpc-id vpc-4139dbf71c5d2ee50
```

---

### Step 8: Create Route Table for Public Subnet

Route tables determine where network traffic is directed.

```bash
aws ec2 create-route-table \
  --vpc-id vpc-4139dbf71c5d2ee50 \
  --query 'RouteTable.RouteTableId' --output text
```
**Result**: `rtb-52266f72025377b73`

---

### Step 9: Add Internet Route

Route all external traffic (0.0.0.0/0) through the Internet Gateway.

```bash
aws ec2 create-route \
  --route-table-id rtb-52266f72025377b73 \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id igw-897f4ecc60e37edd2
```

---

### Step 10: Associate Route Table with Public Subnet

Only the public subnet gets this route table. The private subnet uses the default (no internet route).

```bash
aws ec2 associate-route-table \
  --route-table-id rtb-52266f72025377b73 \
  --subnet-id subnet-a5bc626e84ca06d73
```
**Result**: `rtbassoc-bca94fe0715adb69e`

---

## Verification

### Subnet Configuration
```bash
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-4139dbf71c5d2ee50" \
  --query 'Subnets[*].[SubnetId,CidrBlock]' --output table
```

```
---------------------------------------------
|              DescribeSubnets              |
+---------------------------+---------------+
|  subnet-b50d3ed87a150ab1f |  10.0.2.0/24  |  ← Private
|  subnet-a5bc626e84ca06d73 |  10.0.1.0/24  |  ← Public
+---------------------------+---------------+
```

### Route Table Associations
```bash
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=vpc-4139dbf71c5d2ee50" \
  --query 'RouteTables[*].[RouteTableId,Associations[0].SubnetId]' --output table
```

```
-------------------------------------------------------
|                 DescribeRouteTables                 |
+------------------------+----------------------------+
|  rtb-232f879ef4107b3f7 |  None                      |
|  rtb-97702810f6c843e64 |  None                      |
|  rtb-52266f72025377b73 |  subnet-a5bc626e84ca06d73  |  ← Internet route
+------------------------+----------------------------+
```

---

## Key Concepts Demonstrated

| Concept | Implementation |
|---------|----------------|
| **Network Isolation** | VPC provides isolated network boundary |
| **Subnet Segmentation** | Public (10.0.1.0/24) and Private (10.0.2.0/24) separation |
| **Routing** | Internet Gateway + Route Table = public access |
| **Security Groups** | Firewall rules at resource level (ports, not IAM) |
| **Defense in Depth** | Private subnet has no route to internet |

---

## Security Considerations

| Finding | Severity | Recommendation |
|---------|----------|----------------|
| `0.0.0.0/0` on port 80 | Medium | Review if public access is required |
| `0.0.0.0/0` on port 22 | Critical | Never allow SSH from anywhere |
| Private subnet isolation | Best Practice | Database/internal services stay private |

---

## JSA Agent Mapping

This architecture relates to GP-Copilot's security automation:

| Phase | Agent | Action |
|-------|-------|--------|
| Pre-Deployment | jsa-devsec | Scan Terraform for misconfigs (Checkov, tfsec) |
| Post-Deployment | jsa-infrasec | Monitor for drift, compliance scans (Prowler) |
| Runtime | jsa-secops | Detect anomalies, unauthorized changes |

---

## Next Steps

- [ ] Add NAT Gateway for private subnet outbound access
- [ ] Implement Network ACLs for subnet-level filtering
- [ ] Create Load Balancer in public subnet
- [ ] Automate with Terraform and add to jsa-devsec scanning

---

## Resources

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [CKA Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- Kubernetes equivalent: NetworkPolicy, Services, Ingress