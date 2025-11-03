package main

# Test 1: Policy should deny privileged pods
test_deny_privileged_pod {
  # Fake input (simulates a privileged pod)
  input := {
    "kind": "Pod",
    "spec": {
      "containers": [{
        "name": "nginx",
        "securityContext": {
          "privileged": true
        }
      }]
    }
  }
  
  # Run the policy
  result := deny with input as input
  
  # Assert it denies
  count(result) == 1
}

# Test 2: Policy should allow non-privileged pods
test_allow_non_privileged_pod {
  input := {
    "kind": "Pod",
    "spec": {
      "containers": [{
        "name": "nginx",
        "securityContext": {
          "runAsNonRoot": true
        }
      }]
    }
  }
  
  result := deny with input as input
  
  # Assert it allows (no denials)
  count(result) == 0
}
