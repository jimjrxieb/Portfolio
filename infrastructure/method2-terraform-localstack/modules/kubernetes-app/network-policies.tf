# Network Policies - Layer 3 Defense-in-Depth
# Zero-trust microsegmentation preventing lateral movement

# ============================================================================
# Policy 1: Default Deny All Traffic
# ============================================================================
# Denies all ingress and egress traffic by default
# All other policies explicitly allow only necessary traffic

resource "kubernetes_network_policy" "default_deny_all" {
  metadata {
    name      = "default-deny-all"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Ingress", "Egress"]
  }
}

# ============================================================================
# Policy 2: Allow DNS
# ============================================================================
# Allows all pods to perform DNS lookups via kube-dns/CoreDNS

resource "kubernetes_network_policy" "allow_dns" {
  metadata {
    name      = "allow-dns"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Egress"]

    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }

      ports {
        protocol = "UDP"
        port     = "53"
      }

      ports {
        protocol = "TCP"
        port     = "53"
      }
    }
  }
}

# ============================================================================
# Policy 3: UI Ingress
# ============================================================================
# Allows UI to receive traffic from anywhere (public internet)

resource "kubernetes_network_policy" "ui_ingress" {
  metadata {
    name      = "ui-ingress"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "portfolio-ui"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        # Allow from anywhere (public access)
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }

      ports {
        protocol = "TCP"
        port     = "8080"
      }
    }
  }
}

# ============================================================================
# Policy 4: API Ingress
# ============================================================================
# Allows API to receive traffic ONLY from UI pods
# Prevents direct external access to API

resource "kubernetes_network_policy" "api_ingress" {
  metadata {
    name      = "api-ingress"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "portfolio-api"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "portfolio-ui"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "8000"
      }
    }
  }
}

# ============================================================================
# Policy 5: API to ChromaDB Egress
# ============================================================================
# Allows API to connect to ChromaDB
# Also allows external API calls (Claude API, OpenAI, etc.)

resource "kubernetes_network_policy" "api_to_chroma" {
  metadata {
    name      = "api-to-chroma"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "portfolio-api"
      }
    }

    policy_types = ["Egress"]

    # Allow API to reach ChromaDB
    egress {
      to {
        pod_selector {
          match_labels = {
            app = "chroma"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "8000"
      }
    }

    # Allow API to reach external services (Claude, OpenAI, etc.)
    egress {
      to {
        # Allow all external IPs
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }

      ports {
        protocol = "TCP"
        port     = "443"  # HTTPS
      }

      ports {
        protocol = "TCP"
        port     = "80"  # HTTP
      }
    }
  }
}

# ============================================================================
# Policy 6: ChromaDB Ingress - CRITICAL ISOLATION
# ============================================================================
# Allows ChromaDB to receive traffic ONLY from API
# DENIES all egress except DNS (prevents data exfiltration)
# This is the key security control preventing ChromaDB compromise

resource "kubernetes_network_policy" "chroma_ingress" {
  metadata {
    name      = "chroma-ingress"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "chroma"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Ingress: ONLY from API
    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "portfolio-api"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "8000"
      }
    }

    # Egress: ONLY DNS (no external internet)
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }

      ports {
        protocol = "UDP"
        port     = "53"
      }

      ports {
        protocol = "TCP"
        port     = "53"
      }
    }
  }
}
