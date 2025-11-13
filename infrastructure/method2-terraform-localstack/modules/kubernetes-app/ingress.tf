# Ingress for Portfolio Application
# Routes /api to API service and / to UI service

resource "kubernetes_ingress_v1" "portfolio" {
  metadata {
    name      = "portfolio"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/cors-allow-origin"  = "*"
      "nginx.ingress.kubernetes.io/cors-allow-methods" = "GET, POST, OPTIONS"
      "nginx.ingress.kubernetes.io/cors-allow-headers" = "Content-Type, Authorization"
      "nginx.ingress.kubernetes.io/rewrite-target"     = "/$2"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "portfolio.localtest.me"

      http {
        # API routes - strip /api prefix
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

        # UI routes
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

    # Optional: linksmlm.com route
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
