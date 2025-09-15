package main

# Require NetworkPolicy for every namespace
deny[msg] {
  input.kind == "Namespace"
  not has_network_policy
  msg := "Namespace must have at least one NetworkPolicy"
}

has_network_policy {
  # This would need to be checked in combination with other manifests
  # For now, we'll assume if namespace labels include network policy configs
  input.metadata.labels["network-policy"]
}

# Deny services with type LoadBalancer (use Ingress instead)
deny[msg] {
  input.kind == "Service"
  input.spec.type == "LoadBalancer"
  msg := "LoadBalancer services are not allowed, use Ingress instead"
}

# Deny services with type NodePort in production
deny[msg] {
  input.kind == "Service"
  input.spec.type == "NodePort"
  input.metadata.namespace != "kube-system"
  msg := "NodePort services are not allowed in application namespaces"
}

# Require Ingress to use TLS
deny[msg] {
  input.kind == "Ingress"
  not input.spec.tls
  msg := "Ingress must specify TLS configuration"
}

# Require specific ingress class
deny[msg] {
  input.kind == "Ingress"
  input.spec.ingressClassName != "nginx"
  msg := "Ingress must use 'nginx' ingress class"
}