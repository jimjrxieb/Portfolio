package main

# Require images from allowed registries
deny[msg] {
  input.kind == "Deployment"
  some c
  container := input.spec.template.spec.containers[c]
  not startswith(container.image, "ghcr.io/")
  not startswith(container.image, "chromadb/")
  not startswith(container.image, "busybox:")
  msg := sprintf("Container '%s' uses disallowed registry: %s", [container.name, container.image])
}

# Deny latest tags
deny[msg] {
  input.kind == "Deployment"
  some c
  container := input.spec.template.spec.containers[c]
  endswith(container.image, ":latest")
  msg := sprintf("Container '%s' uses 'latest' tag which is not allowed", [container.name])
}

# Deny missing tags (defaults to latest)
deny[msg] {
  input.kind == "Deployment"
  some c
  container := input.spec.template.spec.containers[c]
  not contains(container.image, ":")
  msg := sprintf("Container '%s' must specify image tag", [container.name])
}

# Require specific image pull policy
deny[msg] {
  input.kind == "Deployment"
  input.spec.template.spec.containers[_].imagePullPolicy == "Always"
  msg := "imagePullPolicy 'Always' is not recommended, use 'IfNotPresent'"
}