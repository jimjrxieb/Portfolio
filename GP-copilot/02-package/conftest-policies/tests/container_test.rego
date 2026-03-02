package main

# Test: Deny root user (UID 0)
test_deny_root_user {
  deny["Container must not run as root user (UID 0)"] with input as {
    "kind": "Deployment",
    "spec": {
      "template": {
        "spec": {
          "containers": [{
            "name": "app",
            "securityContext": {"runAsUser": 0}
          }]
        }
      }
    }
  }
}

# Test: Allow non-root user
test_allow_non_root_user {
  count(deny) == 0 with input as {
    "kind": "Deployment",
    "spec": {
      "template": {
        "spec": {
          "containers": [{
            "name": "app",
            "image": "ghcr.io/jimjrxieb/portfolio-api:v1.0.0",
            "imagePullPolicy": "IfNotPresent",
            "securityContext": {"runAsUser": 10001},
            "resources": {
              "limits": {"cpu": "1", "memory": "1Gi"}
            }
          }]
        }
      }
    }
  }
}

# Test: Deny missing security context
test_deny_missing_security_context {
  msg := "Container 'app' must have securityContext defined"
  deny[msg] with input as {
    "kind": "Deployment",
    "spec": {
      "template": {
        "spec": {
          "containers": [{
            "name": "app"
          }]
        }
      }
    }
  }
}

# Test: Deny privileged container
test_deny_privileged {
  msg := "Container 'app' must not run in privileged mode"
  deny[msg] with input as {
    "kind": "Deployment",
    "spec": {
      "template": {
        "spec": {
          "containers": [{
            "name": "app",
            "securityContext": {
              "privileged": true
            }
          }]
        }
      }
    }
  }
}

# Test: Deny privilege escalation
test_deny_privilege_escalation {
  msg := "Container 'app' must not allow privilege escalation"
  deny[msg] with input as {
    "kind": "Deployment",
    "spec": {
      "template": {
        "spec": {
          "containers": [{
            "name": "app",
            "securityContext": {
              "allowPrivilegeEscalation": true
            }
          }]
        }
      }
    }
  }
}

# Test: Deny missing resource limits
test_deny_missing_resource_limits {
  msg := "Container 'app' must have resource limits defined"
  deny[msg] with input as {
    "kind": "Deployment",
    "spec": {
      "template": {
        "spec": {
          "containers": [{
            "name": "app",
            "securityContext": {"runAsUser": 10001}
          }]
        }
      }
    }
  }
}

# Test: Deny missing memory limit
test_deny_missing_memory_limit {
  msg := "Container 'app' must have memory limits defined"
  deny[msg] with input as {
    "kind": "Deployment",
    "spec": {
      "template": {
        "spec": {
          "containers": [{
            "name": "app",
            "securityContext": {"runAsUser": 10001},
            "resources": {
              "limits": {"cpu": "1"}
            }
          }]
        }
      }
    }
  }
}

# Test: Deny missing CPU limit
test_deny_missing_cpu_limit {
  msg := "Container 'app' must have CPU limits defined"
  deny[msg] with input as {
    "kind": "Deployment",
    "spec": {
      "template": {
        "spec": {
          "containers": [{
            "name": "app",
            "securityContext": {"runAsUser": 10001},
            "resources": {
              "limits": {"memory": "1Gi"}
            }
          }]
        }
      }
    }
  }
}

# Test: Allow secure deployment
test_allow_secure_deployment {
  count(deny) == 0 with input as {
    "kind": "Deployment",
    "metadata": {"name": "secure-app"},
    "spec": {
      "template": {
        "spec": {
          "containers": [{
            "name": "app",
            "image": "ghcr.io/myorg/app:v1.0.0",
            "imagePullPolicy": "IfNotPresent",
            "securityContext": {
              "runAsUser": 10001,
              "runAsNonRoot": true,
              "allowPrivilegeEscalation": false,
              "readOnlyRootFilesystem": true
            },
            "resources": {
              "requests": {"cpu": "100m", "memory": "128Mi"},
              "limits": {"cpu": "1", "memory": "1Gi"}
            }
          }]
        }
      }
    }
  }
}
