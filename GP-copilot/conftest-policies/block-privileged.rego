package main

deny[msg] {
  input.kind == "Pod"
  container := input.spec.containers[_]
  container.securityContext.privileged == true

  msg := sprintf(
    "Privileged container not allowed: %s",
    [container.name]
  )
}
