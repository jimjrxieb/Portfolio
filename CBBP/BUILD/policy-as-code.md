# Policy As Code

The executable policy files stay at the repo root:

```text
policies/conftest/
```

They are active CI/CD inputs, not just documentation. The CBBP folder explains
and maps them, but the pipeline should keep a short, predictable path for tools
such as Conftest and GitHub Actions.

## Why Policies Stay At Root

| Reason | Explanation |
|---|---|
| CI compatibility | `.github/workflows/policy-check.yml` already references `policies/conftest/`. |
| Tool convention | `policies/` is a common root-level location for executable Rego policies. |
| Separation of concerns | Root policies enforce controls; CBBP documents what those controls mean. |
| Lower maintenance | Moving policies would require workflow and command updates. |

Rule of thumb:

```text
Active executable controls stay in tool paths.
CBBP explains, maps, validates, and packages the evidence.
```

## Policy Inventory

| Policy | Purpose | Control themes |
|---|---|---|
| `policies/conftest/kubernetes.rego` | General CKS-style Kubernetes hardening checks. Blocks privileged containers, privilege escalation, root execution, host networking, host namespaces, and weak image tags. | AC-6, CM-6, SC-7, SI-3 |
| `policies/conftest/03-prohibit-insecure-services.rego` | Blocks `NodePort` and unauthorized `LoadBalancer` services. | SC-7 |
| `policies/conftest/05-require-resource-limits.rego` | Requires CPU and memory limits for workload containers. | CM-2, SC-5 |
| `policies/conftest/gateway-api.rego` | Checks Gateway and HTTPRoute boundary expectations, wildcard hostnames, and TLS listener behavior. | SC-7, SC-8, AC-6 |
| `policies/conftest/image-security.rego` | Enforces trusted registries, discourages weak tags, and models image supply-chain expectations. | SA-10, SI-3, CM-2 |
| `policies/conftest/secrets-management.rego` | Detects hardcoded secrets and risky secret handling patterns. | IA-5, SC-28 |
| `policies/conftest/cicd-security.rego` | Models CI/CD pipeline controls such as branch approval, scan execution, secret scanning, image scanning, and signed/verified release expectations. | SA-11, SA-15, CM-3, SI-2 |
| `policies/conftest/exceptions.rego` | Documents project-specific policy exceptions and approved registries. | RA-3, CA-5 |

## How The Policies Run

The primary workflow is:

```text
GitHub pull request
  -> render Helm manifests
  -> run conftest verify
  -> run conftest test against rendered manifests
  -> run conftest test against infrastructure YAML
```

Implemented in:

```text
.github/workflows/policy-check.yml
```

The broader CI/CD workflow also references policy validation during Kubernetes
and Helm checks:

```text
.github/workflows/main.yml
```

## BUILD Role

In CBBP terms, policy-as-code belongs primarily to BUILD because it implements a
preventive control. It stops weak manifests before they become runtime state.

Examples:

- A privileged pod should fail before deployment.
- A `NodePort` service should fail before exposure.
- A container without limits should fail before it can create resource pressure.
- A workload with hardcoded secrets should fail before secrets reach image layers
  or manifests.

## BREAK Role

BREAK still matters because policy-as-code can pass while runtime state drifts.
BREAK validates the live system:

- Are services actually `ClusterIP`?
- Is ChromaDB actually not routed publicly?
- Are pods actually running without privilege escalation?
- Did the admission/policy layer catch what it was supposed to catch?

BUILD writes the guardrail. BREAK tests the guardrail.

## PROVE Role

PROVE packages evidence:

- policy files used
- workflow run result
- rendered manifest tested
- pass/fail output
- exception list
- reviewer or owner decision

For a stronger evidence package, include the exact commit SHA, workflow run URL,
Conftest version, and rendered manifest hash.

## Current Maturity

| Area | Status | Notes |
|---|---|---|
| Kubernetes hardening policies | Implemented | Covers common CKS/PSS checks. |
| Service exposure policy | Implemented | Blocks weak public service types. |
| Resource governance policy | Implemented | Requires limits. |
| Gateway API policy | Implemented | Maps routing to boundary controls. |
| Secrets policy | Implemented | Checks for hardcoded and risky secret patterns. |
| CI/CD security policy | Implemented as model | Useful for review; may need more structured CI input data to fully enforce. |
| Exception handling | Started | Exceptions should stay explicit, reviewed, and narrow. |

## Next Improvements

- Add a short `README.md` directly under `policies/conftest/`.
- Add unit tests for each Rego policy with positive and negative examples.
- Pin Conftest installation by checksum in CI.
- Emit policy results as an artifact for PROVE.
- Track approved exceptions with owner, date, rationale, and expiry.
