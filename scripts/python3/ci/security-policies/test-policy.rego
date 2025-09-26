package main

deny[msg] {
  input.kind == "Deployment"
  input.spec.template.spec.containers[_].image
  contains(input.spec.template.spec.containers[_].image, ":latest")
  msg := "Latest tag is not allowed"
}

deny[msg] {
  input.kind == "Deployment"
  input.spec.template.spec.containers[_].securityContext.runAsUser == 0
  msg := "Running as root is not allowed"
}