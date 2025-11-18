#!/usr/bin/env python3
"""
Deploy OPA Gatekeeper Policies from GP-copilot/gatekeeper-temps/
Run this after installing Gatekeeper and before deploying the application
"""

import subprocess
import sys
import time
import os
from pathlib import Path

def run_command(cmd, check=True, capture_output=False):
    """Run a shell command and return result"""
    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, check=check, capture_output=capture_output, text=True)
    if capture_output:
        return result.stdout.strip(), result.returncode
    return result.returncode == 0

def wait_for_crd(crd_name, timeout=60):
    """Wait for a CRD to be established"""
    print(f"Waiting for CRD '{crd_name}' to be established...")
    cmd = [
        "kubectl", "wait", "--for", "condition=established",
        f"--timeout={timeout}s", f"crd/{crd_name}"
    ]
    return run_command(cmd, check=False)

def get_policy_dir():
    """Get the path to the gatekeeper-temps directory"""
    # Get the script's directory
    script_dir = Path(__file__).parent.resolve()
    # Navigate to GP-copilot/gatekeeper-temps
    policy_dir = script_dir.parent.parent / "GP-copilot" / "gatekeeper-temps"
    return policy_dir

def main():
    print("=" * 60)
    print("Deploying OPA Gatekeeper Policies")
    print("=" * 60)
    print()

    # Find policy directory
    policy_dir = get_policy_dir()

    if not policy_dir.exists():
        print(f"ERROR: Policy directory not found: {policy_dir}")
        print("Expected: GP-copilot/gatekeeper-temps/")
        return 1

    print(f"Policy directory: {policy_dir}")

    # Get all YAML files
    policy_files = sorted(policy_dir.glob("*.yaml"))

    if not policy_files:
        print("ERROR: No YAML files found in gatekeeper-temps directory")
        return 1

    print(f"Found {len(policy_files)} policy files:")
    for f in policy_files:
        print(f"  - {f.name}")
    print()

    print("=" * 60)
    print("Pass 1: Deploying ConstraintTemplates")
    print("=" * 60)
    print("(Constraints will fail on first pass, this is expected)")
    print()

    # First pass: Deploy everything (ConstraintTemplates succeed, Constraints fail)
    for policy_file in policy_files:
        print(f"\nApplying {policy_file.name}...")
        run_command(["kubectl", "apply", "-f", str(policy_file)], check=False)

    print("\n" + "=" * 60)
    print("Waiting for CRDs to be established...")
    print("=" * 60)
    print()

    # Wait for the Portfolio CRDs
    expected_crds = [
        "portfoliopodsecurity.constraints.gatekeeper.sh",
        "portfoliosecuritycontext.constraints.gatekeeper.sh",
        "portfolioimagesecurity.constraints.gatekeeper.sh",
        "portfolioresourcelimits.constraints.gatekeeper.sh"
    ]

    for crd in expected_crds:
        wait_for_crd(crd, timeout=60)

    print("\nWaiting 5 seconds for CRDs to fully propagate...")
    time.sleep(5)

    print("\n" + "=" * 60)
    print("Pass 2: Deploying Constraints")
    print("=" * 60)
    print()

    # Second pass: Deploy everything (Constraints should succeed now)
    all_success = True
    for policy_file in policy_files:
        print(f"\nApplying {policy_file.name}...")
        if not run_command(["kubectl", "apply", "-f", str(policy_file)], check=False):
            all_success = False
            print(f"  WARNING: Failed to apply {policy_file.name}")

    print("\n" + "=" * 60)
    if all_success:
        print("✓ All OPA policies deployed successfully!")
    else:
        print("⚠ Some policies failed to deploy (see warnings above)")
    print("=" * 60)

    print("\nVerify deployment:")
    print("  kubectl get constrainttemplates")
    print("  kubectl get constraints")
    print("  kubectl get portfoliopodsecurity")
    print("  kubectl get portfoliosecuritycontext")
    print("  kubectl get portfolioimagesecurity")
    print("  kubectl get portfolioresourcelimits")
    print()

    return 0 if all_success else 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nDeployment interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)