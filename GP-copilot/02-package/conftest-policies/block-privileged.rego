# @title Block Privileged Containers
# @description Prevents containers from running in privileged mode
# @custom.severity HIGH
# @custom.version 1.1.0
package main

# Deny privileged containers in Deployments
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.privileged == true
  msg := sprintf("Container '%s' cannot run in privileged mode", [container.name])
}

# Deny privileged init containers in Deployments
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.initContainers[_]
  container.securityContext.privileged == true
  msg := sprintf("Init container '%s' cannot run in privileged mode", [container.name])
}

# Deny privileged containers in StatefulSets
deny[msg] {
  input.kind == "StatefulSet"
  container := input.spec.template.spec.containers[_]
  container.securityContext.privileged == true
  msg := sprintf("Container '%s' cannot run in privileged mode", [container.name])
}

# Deny privileged containers in DaemonSets
deny[msg] {
  input.kind == "DaemonSet"
  container := input.spec.template.spec.containers[_]
  container.securityContext.privileged == true
  msg := sprintf("Container '%s' cannot run in privileged mode", [container.name])
}

# Deny privileged containers in Pods (for direct pod creation)
deny[msg] {
  input.kind == "Pod"
  container := input.spec.containers[_]
  container.securityContext.privileged == true
  msg := sprintf("Container '%s' cannot run in privileged mode", [container.name])
}
