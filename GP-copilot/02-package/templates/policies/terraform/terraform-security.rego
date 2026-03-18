package terraform.security

# UNDERSTANDING: Infrastructure as Code = Code is Infrastructure Security
# Terraform plan = pre-deployment security gate
# State file = credential goldmine requiring protection

import future.keywords.contains
import future.keywords.if
import future.keywords.in

metadata := {
    "policy": "terraform-security-baseline",
    "version": "1.0.0",
    "compliance": ["CIS-AWS", "CIS-Azure", "CIS-GCP", "Terraform-Best-Practices"],
    "scope": "multi-cloud-iac-security",
    "last_review": "2024-09-24"
}

# AWS Security Controls

# CRITICAL: S3 bucket encryption
# THREAT: Data breach, regulatory violations
# COMPLIANCE: CIS-AWS 2.1.1, NIST SC-28
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    not has_encryption(resource)
    msg := sprintf("S3 bucket '%s' must have server-side encryption enabled", [resource.address])
}

has_encryption(resource) {
    resource.change.after.server_side_encryption_configuration[_].rule[_].apply_server_side_encryption_by_default
}

# CRITICAL: S3 public access block
# THREAT: Data exposure, Capital One breach pattern
# COMPLIANCE: CIS-AWS 2.1.5
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    not has_public_access_block(resource)
    msg := sprintf("S3 bucket '%s' must have public access block enabled", [resource.address])
}

has_public_access_block(resource) {
    resource.change.after.block_public_acls == true
    resource.change.after.block_public_policy == true
    resource.change.after.ignore_public_acls == true
    resource.change.after.restrict_public_buckets == true
}

# HIGH: RDS encryption at rest
# THREAT: Database breach, credential theft
# COMPLIANCE: CIS-AWS 2.3.1, PCI-DSS 3.4
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    not resource.change.after.storage_encrypted == true
    msg := sprintf("RDS instance '%s' must have storage encryption enabled", [resource.address])
}

# HIGH: RDS backup retention
# THREAT: Data loss, ransomware recovery
# COMPLIANCE: CIS-AWS 2.3.2, SOC2 A1.2
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    to_number(resource.change.after.backup_retention_period) < 7
    msg := sprintf("RDS instance '%s' must have backup retention >= 7 days", [resource.address])
}

# CRITICAL: Security group ingress from 0.0.0.0/0
# THREAT: Unauthorized access, brute force attacks
# COMPLIANCE: CIS-AWS 5.2, NIST SC-7
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_security_group"
    rule := resource.change.after.ingress[_]
    allows_all_traffic(rule)
    msg := sprintf("Security group '%s' allows ingress from 0.0.0.0/0 on port %d",
                   [resource.address, rule.from_port])
}

allows_all_traffic(rule) {
    rule.cidr_blocks[_] == "0.0.0.0/0"
}

allows_all_traffic(rule) {
    rule.ipv6_cidr_blocks[_] == "::/0"
}

# HIGH: EC2 IMDSv2 enforcement
# THREAT: SSRF attacks, credential theft
# COMPLIANCE: CIS-AWS 5.6
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_instance"
    not enforces_imdsv2(resource)
    msg := sprintf("EC2 instance '%s' must enforce IMDSv2 (http_tokens = required)", [resource.address])
}

enforces_imdsv2(resource) {
    resource.change.after.metadata_options[_].http_tokens == "required"
}

# Azure Security Controls

# CRITICAL: Storage account encryption
# THREAT: Data breach, compliance violations
# COMPLIANCE: CIS-Azure 3.1
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_storage_account"
    not resource.change.after.enable_https_traffic_only == true
    msg := sprintf("Storage account '%s' must enable HTTPS-only traffic", [resource.address])
}

# HIGH: Network security group unrestricted access
# THREAT: Lateral movement, unauthorized access
# COMPLIANCE: CIS-Azure 6.1
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_network_security_rule"
    rule := resource.change.after
    rule.source_address_prefix == "*"
    rule.access == "Allow"
    msg := sprintf("NSG rule '%s' allows traffic from any source (*)", [resource.address])
}

# GCP Security Controls

# CRITICAL: GCS bucket uniform access
# THREAT: Confused deputy, ACL bypass
# COMPLIANCE: CIS-GCP 5.1
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_storage_bucket"
    not resource.change.after.uniform_bucket_level_access[_].enabled == true
    msg := sprintf("GCS bucket '%s' must enable uniform bucket-level access", [resource.address])
}

# HIGH: GCE instance public IP
# THREAT: Exposed attack surface, unauthorized access
# COMPLIANCE: CIS-GCP 4.9
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_compute_instance"
    has_public_ip(resource)
    not is_exempted(resource)
    msg := sprintf("GCE instance '%s' should not have public IP - use Cloud NAT", [resource.address])
}

has_public_ip(resource) {
    resource.change.after.network_interface[_].access_config
}

# Cross-Cloud Security

# HIGH: Unencrypted volumes/disks
# THREAT: Data at rest exposure
# COMPLIANCE: NIST SC-28, PCI-DSS 3.4
deny[msg] {
    resource := input.resource_changes[_]
    resource.type in ["aws_ebs_volume", "azurerm_managed_disk", "google_compute_disk"]
    not resource.change.after.encrypted == true
    msg := sprintf("Disk '%s' must be encrypted at rest", [resource.address])
}

# MEDIUM: Missing tags/labels
# THREAT: Resource sprawl, cost overruns
# COMPLIANCE: FinOps, SOC2 CC1.4
warn[msg] {
    resource := input.resource_changes[_]
    resource.type in taggable_resources
    not has_required_tags(resource)
    msg := sprintf("Resource '%s' missing required tags: Environment, Owner, CostCenter", [resource.address])
}

taggable_resources := [
    "aws_instance", "aws_s3_bucket", "aws_db_instance",
    "azurerm_virtual_machine", "azurerm_storage_account",
    "google_compute_instance", "google_storage_bucket"
]

has_required_tags(resource) {
    tags := object.get(resource.change.after, ["tags", "labels"], {})
    tags.Environment
    tags.Owner
    tags.CostCenter
}

# HIGH: State file backend encryption
# THREAT: Credential exposure in Terraform state
# COMPLIANCE: CIS-Terraform 1.1
deny[msg] {
    resource := input.terraform_version
    backend := input.configuration.terraform[_].backend[_]
    backend_type := object.keys(backend)[0]
    not backend_encrypted(backend_type, backend[backend_type])
    msg := sprintf("Terraform backend '%s' must have encryption enabled", [backend_type])
}

backend_encrypted(backend_type, config) {
    backend_type == "s3"
    config.encrypt == true
}

backend_encrypted(backend_type, config) {
    backend_type == "azurerm"
    config.encryption_enabled == true
}

backend_encrypted(backend_type, config) {
    backend_type == "gcs"
    config.encryption_key
}

# MEDIUM: Remote backend required
# THREAT: Local state file credential exposure
# COMPLIANCE: CIS-Terraform 1.2
deny[msg] {
    not input.configuration.terraform[_].backend
    msg := "Terraform must use remote backend (S3, Azure Storage, GCS) - local state prohibited"
}

# Helper functions

is_exempted(resource) {
    # Check for exemption annotation in resource
    exemption := resource.change.after.tags.SecurityExemption
    exemption == "approved"
}

is_exempted(resource) {
    exemption := resource.change.after.labels.security_exemption
    exemption == "approved"
}
