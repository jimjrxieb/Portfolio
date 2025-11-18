# @title Container Security Policy
# @description Enforces container security best practices
# @custom.severity HIGH
# @custom.version 1.1.0
package main

# Deny containers running as root
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.runAsUser == 0
  msg := sprintf("Container '%s' must not run as root user (UID 0)", [container.name])
}

# Deny init containers running as root
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.initContainers[_]
  container.securityContext.runAsUser == 0
  msg := sprintf("Init container '%s' must not run as root user (UID 0)", [container.name])
}

# Deny containers without security context
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.securityContext
  msg := sprintf("Container '%s' must have securityContext defined", [container.name])
}

# Require runAsNonRoot flag
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.runAsNonRoot != true
  msg := sprintf("Container '%s' must set runAsNonRoot: true", [container.name])
}

# Deny privileged containers
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.privileged == true
  msg := sprintf("Container '%s' must not run in privileged mode", [container.name])
}

# Deny containers with allowPrivilegeEscalation
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.allowPrivilegeEscalation == true
  msg := sprintf("Container '%s' must not allow privilege escalation", [container.name])
}

# Require resource limits
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits
  msg := sprintf("Container '%s' must have resource limits defined", [container.name])
}

# Require memory limits
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits.memory
  msg := sprintf("Container '%s' must have memory limits defined", [container.name])
}

# Require CPU limits
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits.cpu
  msg := sprintf("Container '%s' must have CPU limits defined", [container.name])
}

# Deny dangerous capabilities
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  capability := container.securityContext.capabilities.add[_]
  dangerous_capability(capability)
  msg := sprintf("Container '%s' cannot add dangerous capability '%s'", [container.name, capability])
}

# Require read-only root filesystem (with exceptions)
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.securityContext.readOnlyRootFilesystem
  not exception_container(container.name)
  msg := sprintf("Container '%s' should use readOnlyRootFilesystem: true", [container.name])
}

# Require dropping ALL capabilities
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.securityContext.capabilities.drop
  msg := sprintf("Container '%s' must drop capabilities", [container.name])
}

# Helper function for dangerous capabilities
dangerous_capability(cap) {
  cap == "SYS_ADMIN"
}

dangerous_capability(cap) {
  cap == "NET_ADMIN"
}

dangerous_capability(cap) {
  cap == "SYS_TIME"
}

dangerous_capability(cap) {
  cap == "SYS_MODULE"
}

dangerous_capability(cap) {
  cap == "SYS_PTRACE"
}

dangerous_capability(cap) {
  cap == "DAC_OVERRIDE"
}

# Helper function for containers that need write access
exception_container(name) {
  name == "chromadb"
}

exception_container(name) {
  name == "postgres"
}
