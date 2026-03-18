# ============================================================================
# OPA/Conftest Policy: IAM Security (PCI-DSS 7.1, 8.2, CIS AWS 1.1-1.22)
# ============================================================================
# VALIDATES: Terraform IAM configuration before deployment
# BLOCKS: terraform apply if violations found
# ============================================================================

package terraform.iam

import future.keywords.contains
import future.keywords.if

# DENY: IAM policy uses wildcard actions (PCI-DSS 7.1, CIS AWS 1.16)
deny[msg] {
    policy := input.resource.aws_iam_policy[name]
    statement := policy.policy[_].Statement[_]
    is_wildcard_action(statement)
    msg := sprintf("IAM policy '%s' uses wildcard action '*' (PCI-DSS 7.1)", [name])
}

# Helper: Check if statement has wildcard action
is_wildcard_action(statement) {
    statement.Action == "*"
}

is_wildcard_action(statement) {
    statement.Action[_] == "*"
}

# DENY: IAM policy uses wildcard resources (PCI-DSS 7.1, CIS AWS 1.16)
deny[msg] {
    policy := input.resource.aws_iam_policy[name]
    statement := policy.policy[_].Statement[_]
    is_wildcard_resource(statement)
    msg := sprintf("IAM policy '%s' uses wildcard resource '*' (PCI-DSS 7.1)", [name])
}

# Helper: Check if statement has wildcard resource
is_wildcard_resource(statement) {
    statement.Resource == "*"
}

is_wildcard_resource(statement) {
    statement.Resource[_] == "*"
}

# DENY: IAM user with access keys (prefer IAM roles, PCI-DSS 8.2.1)
deny[msg] {
    user := input.resource.aws_iam_user[name]
    has_access_key(name)
    msg := sprintf("IAM user '%s' has access keys - use IAM roles instead (PCI-DSS 8.2.1)", [name])
}

# Helper: Check if user has access keys
has_access_key(user_name) {
    input.resource.aws_iam_access_key[_].user[_] == sprintf("aws_iam_user.%s.name", [user_name])
}

# DENY: IAM role with overly permissive assume role policy
deny[msg] {
    role := input.resource.aws_iam_role[name]
    statement := role.assume_role_policy[_].Statement[_]
    is_public_assume_role(statement)
    msg := sprintf("IAM role '%s' allows public assume role (CIS AWS 1.16)", [name])
}

# Helper: Check if assume role policy is too permissive
is_public_assume_role(statement) {
    statement.Principal == "*"
}

is_public_assume_role(statement) {
    statement.Principal.AWS == "*"
}

# DENY: IAM policy allows credentials exposure
deny[msg] {
    policy := input.resource.aws_iam_policy[name]
    statement := policy.policy[_].Statement[_]
    allows_credentials_exposure(statement)
    msg := sprintf("IAM policy '%s' allows credentials exposure (iam:GetUser, iam:ListAccessKeys)", [name])
}

# Helper: Check if policy allows credential enumeration
allows_credentials_exposure(statement) {
    dangerous_actions := ["iam:GetUser", "iam:ListAccessKeys", "iam:GetAccessKeyLastUsed"]
    statement.Action[_] == dangerous_actions[_]
}

# DENY: Root account access keys exist (CIS AWS 1.12)
deny[msg] {
    user := input.resource.aws_iam_user[name]
    name == "root"
    msg := "Root account should not have access keys (CIS AWS 1.12)"
}

# WARN: IAM policy overly broad (multiple wildcard actions)
warn[msg] {
    policy := input.resource.aws_iam_policy[name]
    statement := policy.policy[_].Statement[_]
    wildcard_count := count([a | a := statement.Action[_]; contains(a, "*")])
    wildcard_count > 3
    msg := sprintf("IAM policy '%s' has %d wildcard actions - consider least privilege", [name, wildcard_count])
}

# WARN: IAM role not using MFA for assume role
warn[msg] {
    role := input.resource.aws_iam_role[name]
    statement := role.assume_role_policy[_].Statement[_]
    not has_mfa_condition(statement)
    contains(name, "admin")
    msg := sprintf("IAM role '%s' should require MFA for assume role", [name])
}

# Helper: Check if statement requires MFA
has_mfa_condition(statement) {
    statement.Condition.Bool["aws:MultiFactorAuthPresent"] == "true"
}
