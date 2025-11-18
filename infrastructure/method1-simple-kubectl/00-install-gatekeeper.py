#!/usr/bin/env python3
"""
Install OPA Gatekeeper via Helm
Run this before deploying the application
"""

import subprocess
import sys
import time

def run_command(cmd, check=True, capture_output=False):
    """Run a shell command and return result"""
    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, check=check, capture_output=capture_output, text=True)
    if capture_output:
        return result.stdout.strip()
    return result.returncode == 0

def wait_for_pods(namespace, label, timeout=300):
    """Wait for pods to be ready"""
    print(f"Waiting for pods with label '{label}' in namespace '{namespace}'...")
    cmd = [
        "kubectl", "wait", "--for=condition=ready",
        f"--timeout={timeout}s", "pods", "-l", label, "-n", namespace
    ]
    return run_command(cmd, check=False)

def check_namespace_exists(namespace):
    """Check if a namespace exists"""
    result = subprocess.run(
        ["kubectl", "get", "namespace", namespace],
        capture_output=True,
        text=True
    )
    return result.returncode == 0

def main():
    print("=" * 60)
    print("Installing OPA Gatekeeper")
    print("=" * 60)
    print()

    # Check if Gatekeeper is already installed
    if check_namespace_exists("gatekeeper-system"):
        print("✓ Gatekeeper namespace already exists")
        print("  Skipping installation")
        return 0

    print("Step 1: Adding Gatekeeper Helm repository...")
    if not run_command(["helm", "repo", "add", "gatekeeper",
                       "https://open-policy-agent.github.io/gatekeeper/charts"]):
        print("ERROR: Failed to add Helm repository")
        return 1

    print("\nStep 2: Updating Helm repositories...")
    if not run_command(["helm", "repo", "update"]):
        print("ERROR: Failed to update Helm repositories")
        return 1

    print("\nStep 3: Installing Gatekeeper...")
    install_cmd = [
        "helm", "install", "gatekeeper", "gatekeeper/gatekeeper",
        "--namespace", "gatekeeper-system",
        "--create-namespace",
        "--set", "replicas=3",
        "--set", "audit.replicas=1",
        "--set", "validatingWebhookConfiguration.failurePolicy=Ignore",
        "--wait"
    ]

    if not run_command(install_cmd):
        print("ERROR: Failed to install Gatekeeper")
        return 1

    print("\n✓ Gatekeeper installed successfully")

    print("\nStep 4: Waiting for Gatekeeper pods to be ready...")
    if not wait_for_pods("gatekeeper-system", "gatekeeper.sh/operation=webhook"):
        print("WARNING: Some pods may not be ready yet")

    # Give webhooks time to register
    print("\nWaiting 10 seconds for webhooks to register...")
    time.sleep(10)

    print("\n" + "=" * 60)
    print("✓ Gatekeeper installation complete!")
    print("=" * 60)
    print("\nVerify installation:")
    print("  kubectl get pods -n gatekeeper-system")
    print("  kubectl get crd | grep gatekeeper")
    print()

    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInstallation interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nERROR: {e}")
        sys.exit(1)