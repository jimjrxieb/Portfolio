package kubernetes.admission.exceptions

# Portfolio-specific exceptions for conftest policies
# These override FAIL rules that don't apply to this project

import data.kubernetes

# ChromaDB needs CHOWN, DAC_OVERRIDE, SETUID, SETGID for data directory ownership
exception_chroma_capabilities {
    input.kind == "Deployment"
    input.metadata.name == "portfolio-portfolio-app-chroma"
}

# Approved registries for Portfolio project
# Matches Gatekeeper portfolio-allowed-repos constraint
approved_registries := [
    "ghcr.io/jimjrxieb/",
    "docker.io/library/",
    "chromadb/chroma",
    "nginx:",
    "python:",
    "node:",
    "registry.k8s.io/",
    "quay.io/jetstack/",
]
