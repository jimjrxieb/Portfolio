#!/usr/bin/env python3
"""
Method 1: Complete Portfolio Deployment Orchestrator

This script orchestrates the complete deployment in the correct order:
1. Install OPA Gatekeeper
2. Deploy OPA Policies from GP-copilot/gatekeeper-temps/
3. Deploy Portfolio application (namespace, secrets, storage, services)
4. Deploy Cloudflare Tunnel

Usage:
    python3 deploy.py              # Full deployment
    python3 deploy.py --skip-gatekeeper     # Skip Gatekeeper installation
    python3 deploy.py --skip-cloudflare     # Skip Cloudflare deployment
"""

import subprocess
import sys
import argparse
from pathlib import Path

class Color:
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

def print_header(text):
    """Print a formatted header"""
    print("\n" + "=" * 60)
    print(f"{Color.BLUE}{text}{Color.NC}")
    print("=" * 60)

def print_success(text):
    """Print success message"""
    print(f"{Color.GREEN}✓ {text}{Color.NC}")

def print_warning(text):
    """Print warning message"""
    print(f"{Color.YELLOW}⚠ {text}{Color.NC}")

def print_error(text):
    """Print error message"""
    print(f"{Color.RED}✗ {text}{Color.NC}")

def run_script(script_path):
    """Run a Python script and return success status"""
    print(f"\nExecuting: {script_path.name}")
    result = subprocess.run([sys.executable, str(script_path)])
    return result.returncode == 0

def run_command(cmd, check=True):
    """Run a shell command"""
    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, check=check)
    return result.returncode == 0

def wait_for_deployment(namespace, deployment, timeout=300):
    """Wait for deployment to be available"""
    print(f"Waiting for deployment '{deployment}' in namespace '{namespace}'...")
    cmd = [
        "kubectl", "wait", "--for=condition=available",
        f"--timeout={timeout}s", f"deployment/{deployment}", "-n", namespace
    ]
    return run_command(cmd, check=False)

def main():
    parser = argparse.ArgumentParser(description="Deploy Portfolio Method 1")
    parser.add_argument("--skip-gatekeeper", action="store_true",
                       help="Skip Gatekeeper and OPA policy installation")
    parser.add_argument("--skip-cloudflare", action="store_true",
                       help="Skip Cloudflare tunnel deployment")
    parser.add_argument("--skip-secrets", action="store_true",
                       help="Skip secret creation (assumes secrets already exist)")

    args = parser.parse_args()

    script_dir = Path(__file__).parent.resolve()

    print_header("Method 1: Portfolio Deployment")
    print("This will deploy the complete Portfolio stack")
    print()

    # Stage 1: Install Gatekeeper
    if not args.skip_gatekeeper:
        print_header("Stage 1: Install OPA Gatekeeper")
        gatekeeper_script = script_dir / "00-install-gatekeeper.py"

        if not gatekeeper_script.exists():
            print_error(f"Script not found: {gatekeeper_script}")
            return 1

        if not run_script(gatekeeper_script):
            print_error("Gatekeeper installation failed")
            return 1

        print_success("Gatekeeper installation complete")

        # Stage 2: Deploy OPA Policies
        print_header("Stage 2: Deploy OPA Policies")
        opa_script = script_dir / "00-deploy-opa-policies.py"

        if not opa_script.exists():
            print_error(f"Script not found: {opa_script}")
            return 1

        if not run_script(opa_script):
            print_warning("OPA policy deployment had warnings, continuing...")
        else:
            print_success("OPA policies deployed")
    else:
        print_warning("Skipping Gatekeeper and OPA policy installation")

    # Stage 3: Deploy Portfolio Application
    print_header("Stage 3: Deploy Portfolio Application")

    # 3.1: Create namespace
    print("\n3.1: Creating portfolio namespace...")
    if not run_command(["kubectl", "apply", "-f", str(script_dir / "01-namespace.yaml")]):
        print_error("Failed to create namespace")
        return 1
    print_success("Namespace created")

    # 3.2: Create secrets
    if not args.skip_secrets:
        print("\n3.2: Creating secrets from .env...")
        secrets_script = script_dir / "00-create-secrets.py"

        if secrets_script.exists():
            if not run_script(secrets_script):
                print_error("Failed to create secrets")
                return 1
            print_success("Secrets created")
        else:
            print_warning("Secrets script not found, skipping")
    else:
        print_warning("Skipping secret creation")

    # 3.3: Create persistent volume
    print("\n3.3: Creating persistent volume...")
    if not run_command(["kubectl", "apply", "-f", str(script_dir / "03-chroma-pv-local.yaml")]):
        print_error("Failed to create persistent volume")
        return 1
    print_success("Persistent volume created")

    # 3.4: Deploy ChromaDB
    print("\n3.4: Deploying ChromaDB...")
    if not run_command(["kubectl", "apply", "-f", str(script_dir / "04-chroma-deployment.yaml")]):
        print_error("Failed to deploy ChromaDB")
        return 1
    print_success("ChromaDB deployment created")

    # 3.5: Deploy API
    print("\n3.5: Deploying Portfolio API...")
    if not run_command(["kubectl", "apply", "-f", str(script_dir / "05-api-deployment.yaml")]):
        print_error("Failed to deploy API")
        return 1
    print_success("API deployment created")

    # 3.6: Deploy UI
    print("\n3.6: Deploying Portfolio UI...")
    if not run_command(["kubectl", "apply", "-f", str(script_dir / "06-ui-deployment.yaml")]):
        print_error("Failed to deploy UI")
        return 1
    print_success("UI deployment created")

    # 3.7: Create ingress
    print("\n3.7: Creating ingress...")
    if not run_command(["kubectl", "apply", "-f", str(script_dir / "07-ingress.yaml")]):
        print_error("Failed to create ingress")
        return 1
    print_success("Ingress created")

    # 3.8: Apply network policies if they exist
    network_policies_dir = script_dir / "k8s-security" / "network-policies"
    if network_policies_dir.exists():
        print("\n3.8: Applying network policies...")
        if not run_command(["kubectl", "apply", "-f", str(network_policies_dir) + "/"]):
            print_warning("Some network policies may have failed")
        else:
            print_success("Network policies applied")

    # Wait for deployments to be ready
    print("\n3.9: Waiting for deployments to be ready...")
    deployments = [
        ("portfolio", "chroma"),
        ("portfolio", "portfolio-api"),
        ("portfolio", "portfolio-ui")
    ]

    for namespace, deployment in deployments:
        if not wait_for_deployment(namespace, deployment):
            print_warning(f"{deployment} may not be ready yet")

    print_success("Portfolio application deployed")

    # Stage 4: Install Cloudflare Tunnel (System Service)
    if not args.skip_cloudflare:
        print_header("Stage 4: Install Cloudflare Tunnel")
        cloudflare_script = script_dir / "99-deploy-cloudflare.py"

        if cloudflare_script.exists():
            if not run_script(cloudflare_script):
                print_warning("Cloudflare tunnel installation failed or skipped")
            else:
                print_success("Cloudflare tunnel installed as system service")
        else:
            print_warning("Cloudflare script not found, skipping")
    else:
        print_warning("Skipping Cloudflare tunnel installation")

    # Final summary
    print_header("Deployment Complete!")
    print("\nDeployed Components:")
    if not args.skip_gatekeeper:
        print("  ✓ OPA Gatekeeper (gatekeeper-system namespace)")
        print("  ✓ OPA Security Policies")
    print("  ✓ Portfolio Application (portfolio namespace)")
    if not args.skip_cloudflare:
        print("  ✓ Cloudflare Tunnel (system service)")

    print("\nAccess your application:")
    print("  Local:  http://portfolio.localtest.me/")
    print("  Domain: http://linksmlm.com/ (if Cloudflare tunnel is configured)")

    print("\nCheck status:")
    print("  kubectl get pods -n portfolio")
    if not args.skip_gatekeeper:
        print("  kubectl get pods -n gatekeeper-system")
    if not args.skip_cloudflare:
        print("  sudo systemctl status cloudflared")

    print("\nView logs:")
    print("  kubectl logs -n portfolio deploy/portfolio-api")
    print("  kubectl logs -n portfolio deploy/portfolio-ui")
    if not args.skip_cloudflare:
        print("  sudo journalctl -u cloudflared -f")
    print()

    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print(f"\n\n{Color.YELLOW}Deployment interrupted by user{Color.NC}")
        sys.exit(1)
    except Exception as e:
        print(f"\n{Color.RED}ERROR: {e}{Color.NC}")
        import traceback
        traceback.print_exc()
        sys.exit(1)