# NIST 800-53 SC-7: BOUNDARY PROTECTION
# NIST 800-53 SC-7(4): EXTERNAL TELECOMMUNICATIONS SERVICES
#
# Purpose: Prohibit the use of insecure service types (NodePort, LoadBalancer).
# All external traffic must go through an authorized Ingress with TLS.
# Portfolio uses ClusterIP + Traefik Ingress — this policy enforces that pattern.
#
# Usage: conftest test infrastructure/ --policy GP-copilot/conftest-policies/ --all-namespaces

package main

deny[msg] {
  input.kind == "Service"
  input.spec.type == "NodePort"
  msg := sprintf("Service '%v' uses prohibited type 'NodePort'. Use ClusterIP with Ingress instead (NIST SC-7).", [input.metadata.name])
}

deny[msg] {
  input.kind == "Service"
  input.spec.type == "LoadBalancer"
  # Allow LoadBalancer if specifically authorized via annotation
  not input.metadata.annotations["linkops.io/authorized-loadbalancer"] == "true"
  msg := sprintf("Service '%v' uses 'LoadBalancer' without explicit authorization. Use ClusterIP with Ingress (NIST SC-7).", [input.metadata.name])
}

# Warn if a service doesn't have a selector (could be a misconfiguration)
warn[msg] {
  input.kind == "Service"
  not input.spec.selector
  msg := sprintf("Service '%v' has no selector defined. Ensure this is intentional.", [input.metadata.name])
}
