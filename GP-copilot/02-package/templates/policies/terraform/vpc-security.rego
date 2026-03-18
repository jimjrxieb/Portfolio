# ============================================================================
# OPA/Conftest Policy: VPC Security (PCI-DSS 1.2, 1.3, CIS AWS 5.1-5.4)
# ============================================================================
# VALIDATES: Terraform VPC configuration before deployment
# BLOCKS: terraform apply if violations found
# ============================================================================

package terraform.vpc

import future.keywords.contains
import future.keywords.if

# DENY: VPC missing Flow Logs (CIS AWS 3.9, PCI-DSS 10.1)
deny[msg] {
    resource := input.resource.aws_vpc[name]
    not has_flow_logs(name)
    msg := sprintf("VPC '%s' missing Flow Logs (CIS AWS 3.9, PCI-DSS 10.1)", [name])
}

# Helper: Check if VPC has Flow Logs
has_flow_logs(vpc_name) {
    input.resource.aws_flow_log[_].vpc_id[_] == sprintf("aws_vpc.%s.id", [vpc_name])
}

# DENY: VPC using default security group (CIS AWS 5.3)
deny[msg] {
    resource := input.resource.aws_default_security_group[name]
    count(resource.ingress) > 0
    msg := sprintf("Default security group '%s' has ingress rules (CIS AWS 5.3)", [name])
}

# DENY: Security group allows 0.0.0.0/0 ingress (except ALB on 443)
deny[msg] {
    resource := input.resource.aws_security_group[name]
    rule := resource.ingress[_]
    has_public_cidr(rule)
    not is_alb_https(name, rule)
    msg := sprintf("Security group '%s' allows 0.0.0.0/0 ingress on port %d (PCI-DSS 1.2.1)", [name, rule.from_port])
}

# Helper: Check if CIDR is public
has_public_cidr(rule) {
    rule.cidr_blocks[_] == "0.0.0.0/0"
}

# Helper: Check if this is ALB HTTPS (allowed exception)
is_alb_https(name, rule) {
    contains(name, "alb")
    rule.from_port == 443
}

# DENY: Database in public subnet (PCI-DSS 1.3.1)
deny[msg] {
    db := input.resource.aws_db_instance[name]
    db.publicly_accessible == true
    msg := sprintf("Database '%s' is publicly accessible (PCI-DSS 1.3.1)", [name])
}

# DENY: VPC missing private subnets (PCI-DSS 1.3)
deny[msg] {
    vpc := input.resource.aws_vpc[name]
    not has_private_subnets(name)
    msg := sprintf("VPC '%s' missing private subnets (PCI-DSS 1.3)", [name])
}

# Helper: Check if VPC has private subnets
has_private_subnets(vpc_name) {
    subnet := input.resource.aws_subnet[_]
    contains(subnet.tags.Name, "private")
}

# WARN: VPC not using multiple AZs (high availability)
warn[msg] {
    vpc := input.resource.aws_vpc[name]
    subnets := [s | s := input.resource.aws_subnet[_]; s.vpc_id[_] == sprintf("aws_vpc.%s.id", [name])]
    count(subnets) < 2
    msg := sprintf("VPC '%s' should use multiple availability zones", [name])
}
