# ============================================================================
# OPA/Conftest Policy: S3 Security (PCI-DSS 3.4, 10.1, CIS AWS 2.1-2.3)
# ============================================================================
# VALIDATES: Terraform S3 configuration before deployment
# BLOCKS: terraform apply if violations found
# ============================================================================

package terraform.s3

import future.keywords.contains
import future.keywords.if

# DENY: S3 bucket without encryption (PCI-DSS 3.4, CIS AWS 2.1.1)
deny[msg] {
    bucket := input.resource.aws_s3_bucket[name]
    not has_encryption(name)
    msg := sprintf("S3 bucket '%s' missing encryption (PCI-DSS 3.4, CIS AWS 2.1.1)", [name])
}

# Helper: Check if bucket has encryption
has_encryption(bucket_name) {
    input.resource.aws_s3_bucket_server_side_encryption_configuration[_].bucket[_] == sprintf("aws_s3_bucket.%s.id", [bucket_name])
}

# DENY: S3 bucket without versioning (PCI-DSS 10.5.3, CIS AWS 2.1.3)
deny[msg] {
    bucket := input.resource.aws_s3_bucket[name]
    versioning := input.resource.aws_s3_bucket_versioning[name]
    versioning.versioning_configuration[_].status != "Enabled"
    msg := sprintf("S3 bucket '%s' versioning not enabled (PCI-DSS 10.5.3)", [name])
}

# DENY: S3 bucket allows public access (PCI-DSS 1.2.1, CIS AWS 2.1.5)
deny[msg] {
    bucket := input.resource.aws_s3_bucket[name]
    acl := input.resource.aws_s3_bucket_acl[name]
    is_public_acl(acl.acl)
    msg := sprintf("S3 bucket '%s' has public ACL '%s' (PCI-DSS 1.2.1)", [name, acl.acl])
}

# Helper: Check if ACL is public
is_public_acl(acl) {
    acl == "public-read"
}

is_public_acl(acl) {
    acl == "public-read-write"
}

# DENY: S3 bucket without logging (PCI-DSS 10.1, CIS AWS 2.1.4)
deny[msg] {
    bucket := input.resource.aws_s3_bucket[name]
    not has_logging(name)
    not is_log_bucket(name)
    msg := sprintf("S3 bucket '%s' missing access logging (PCI-DSS 10.1)", [name])
}

# Helper: Check if bucket has logging
has_logging(bucket_name) {
    input.resource.aws_s3_bucket_logging[_].bucket[_] == sprintf("aws_s3_bucket.%s.id", [bucket_name])
}

# Helper: Check if this IS the log bucket (no recursive logging)
is_log_bucket(bucket_name) {
    contains(bucket_name, "audit_logs")
}

is_log_bucket(bucket_name) {
    contains(bucket_name, "logs")
}

# DENY: S3 bucket public access block not enabled (CIS AWS 2.1.5)
deny[msg] {
    bucket := input.resource.aws_s3_bucket[name]
    not has_public_access_block(name)
    msg := sprintf("S3 bucket '%s' missing public access block (CIS AWS 2.1.5)", [name])
}

# Helper: Check if bucket has public access block
has_public_access_block(bucket_name) {
    block := input.resource.aws_s3_bucket_public_access_block[bucket_name]
    block.block_public_acls == true
    block.block_public_policy == true
    block.ignore_public_acls == true
    block.restrict_public_buckets == true
}

# DENY: S3 bucket using KMS but not customer-managed key (PCI-DSS 3.4)
deny[msg] {
    encryption := input.resource.aws_s3_bucket_server_side_encryption_configuration[name]
    algorithm := encryption.rule[_].apply_server_side_encryption_by_default[_].sse_algorithm
    algorithm == "aws:kms"
    not encryption.rule[_].apply_server_side_encryption_by_default[_].kms_master_key_id
    msg := sprintf("S3 bucket '%s' using aws:kms but no customer-managed key specified", [name])
}

# WARN: S3 bucket not using KMS (recommend upgrade from AES256)
warn[msg] {
    encryption := input.resource.aws_s3_bucket_server_side_encryption_configuration[name]
    algorithm := encryption.rule[_].apply_server_side_encryption_by_default[_].sse_algorithm
    algorithm == "AES256"
    msg := sprintf("S3 bucket '%s' using AES256 - consider upgrading to aws:kms", [name])
}
