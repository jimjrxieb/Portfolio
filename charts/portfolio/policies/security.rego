package main

# Deny containers running as root
deny[msg] {
  input.kind == "Deployment"
  some c
  container := input.spec.template.spec.containers[c]
  container.securityContext.runAsUser == 0
  msg := sprintf("Container '%s' is running as root user", [container.name])
}

# Deny containers with privilege escalation
deny[msg] {
  input.kind == "Deployment"
  some c
  container := input.spec.template.spec.containers[c]
  container.securityContext.allowPrivilegeEscalation == true
  msg := sprintf("Container '%s' allows privilege escalation", [container.name])
}

# Require read-only root filesystem (with exceptions for init containers)
deny[msg] {
  input.kind == "Deployment"
  some c
  container := input.spec.template.spec.containers[c]
  not container.securityContext.readOnlyRootFilesystem
  msg := sprintf("Container '%s' must have readOnlyRootFilesystem: true", [container.name])
}

# Require seccomp profile
deny[msg] {
  input.kind == "Deployment"
  some c
  container := input.spec.template.spec.containers[c]
  not container.securityContext.seccompProfile.type
  msg := sprintf("Container '%s' must specify seccompProfile", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  some c
  container := input.spec.template.spec.containers[c]
  container.securityContext.seccompProfile.type != "RuntimeDefault"
  msg := sprintf("Container '%s' must use seccompProfile: RuntimeDefault", [container.name])
}

# Require non-root user
deny[msg] {
  input.kind == "Deployment"
  some c
  container := input.spec.template.spec.containers[c]
  not container.securityContext.runAsNonRoot
  msg := sprintf("Container '%s' must set runAsNonRoot: true", [container.name])
}

# Require dropped capabilities
deny[msg] {
  input.kind == "Deployment"
  some c
  container := input.spec.template.spec.containers[c]
  not container.securityContext.capabilities.drop
  msg := sprintf("Container '%s' must drop all capabilities", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  some c
  container := input.spec.template.spec.containers[c]
  capabilities := container.securityContext.capabilities.drop
  not any_capability_all(capabilities)
  msg := sprintf("Container '%s' must drop ALL capabilities", [container.name])
}

any_capability_all(capabilities) {
  capabilities[_] == "ALL"
}

# Require resource limits
deny[msg] {
  input.kind == "Deployment"
  some c
  container := input.spec.template.spec.containers[c]
  not container.resources.limits.memory
  msg := sprintf("Container '%s' must have memory limits", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  some c
  container := input.spec.template.spec.containers[c]
  not container.resources.limits.cpu
  msg := sprintf("Container '%s' must have CPU limits", [container.name])
}

# Require service account token auto-mount to be disabled
deny[msg] {
  input.kind == "ServiceAccount"
  input.automountServiceAccountToken != false
  msg := "ServiceAccount must have automountServiceAccountToken: false"
}

# Require liveness and readiness probes
deny[msg] {
  input.kind == "Deployment"
  some c
  container := input.spec.template.spec.containers[c]
  not container.livenessProbe
  msg := sprintf("Container '%s' must have livenessProbe", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  some c
  container := input.spec.template.spec.containers[c]
  not container.readinessProbe
  msg := sprintf("Container '%s' must have readinessProbe", [container.name])
}