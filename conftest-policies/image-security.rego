package main

# Deny latest tags in production
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("Container '%s' uses 'latest' tag which is not allowed in production", [container.name])
}

# Deny images without tags
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not contains(container.image, ":")
  msg := sprintf("Container '%s' must specify an image tag", [container.name])
}

# Require trusted registries
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not startswith(container.image, "ghcr.io/")
  not startswith(container.image, "chromadb/")
  not startswith(container.image, "registry.k8s.io/")
  msg := sprintf("Container '%s' must use images from trusted registries (ghcr.io, chromadb, registry.k8s.io)", [container.name])
}

# Require image pull policy
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.imagePullPolicy
  msg := sprintf("Container '%s' must specify imagePullPolicy", [container.name])
}

# Require Always pull policy for latest tags
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  container.imagePullPolicy != "Always"
  msg := sprintf("Container '%s' with latest tag must use imagePullPolicy: Always", [container.name])
}