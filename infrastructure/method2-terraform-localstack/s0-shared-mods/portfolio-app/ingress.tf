# Ingress for Portfolio API - with path rewriting
# Routes /api/* to API service, stripping /api prefix

resource "kubernetes_ingress_v1" "portfolio_api" {
  metadata {
    name      = "portfolio-api"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/cors-allow-origin"  = "*"
      "nginx.ingress.kubernetes.io/cors-allow-methods" = "GET, POST, OPTIONS"
      "nginx.ingress.kubernetes.io/cors-allow-headers" = "Content-Type, Authorization"
      "nginx.ingress.kubernetes.io/use-regex"          = "true"
      "nginx.ingress.kubernetes.io/rewrite-target"     = "/$2"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "portfolio.localtest.me"

      http {
        path {
          path      = "/api(/|$)(.*)"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = kubernetes_service.api.metadata[0].name
              port {
                number = 8000
              }
            }
          }
        }
      }
    }

    rule {
      host = "linksmlm.com"

      http {
        path {
          path      = "/api(/|$)(.*)"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = kubernetes_service.api.metadata[0].name
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }
}

# Ingress for Portfolio UI - no path rewriting
# Routes all non-API traffic to UI service

resource "kubernetes_ingress_v1" "portfolio_ui" {
  metadata {
    name      = "portfolio-ui"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/cors-allow-origin"  = "*"
      "nginx.ingress.kubernetes.io/cors-allow-methods" = "GET, POST, OPTIONS"
      "nginx.ingress.kubernetes.io/cors-allow-headers" = "Content-Type, Authorization"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "portfolio.localtest.me"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.ui.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    rule {
      host = "linksmlm.com"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.ui.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
