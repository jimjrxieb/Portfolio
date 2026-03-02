# @title Image Security Policy
# @description Validates container image sources and tags
# @custom.severity HIGH
# @custom.version 1.1.0
package main

# Warn about latest tags (not deny - align with Gatekeeper)
warn[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("Container '%s' uses 'latest' tag - consider using specific version for production", [container.name])
}

# Deny images without tags
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not contains(container.image, ":")
  not contains(container.image, "@sha256:")
  msg := sprintf("Container '%s' must specify an image tag or digest", [container.name])
}

# Require trusted registries
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not trusted_registry(container.image)
  msg := sprintf("Container '%s' must use images from trusted registries", [container.name])
}

# Check init containers for trusted registries
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.initContainers[_]
  not trusted_registry(container.image)
  msg := sprintf("Init container '%s' must use images from trusted registries", [container.name])
}

# Helper function for trusted registries
trusted_registry(image) {
  startswith(image, "ghcr.io/jimjrxieb/")
}

trusted_registry(image) {
  startswith(image, "shadow-link-industries/")
}

trusted_registry(image) {
  startswith(image, "chromadb/")
}

trusted_registry(image) {
  startswith(image, "registry.k8s.io/")
}

trusted_registry(image) {
  startswith(image, "mcr.microsoft.com/")
}

trusted_registry(image) {
  startswith(image, "gcr.io/distroless/")
}

# Require image pull policy for non-digest images
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.imagePullPolicy
  not contains(container.image, "@sha256:")
  msg := sprintf("Container '%s' must specify imagePullPolicy", [container.name])
}
