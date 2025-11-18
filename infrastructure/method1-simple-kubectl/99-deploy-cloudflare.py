#!/usr/bin/env python3
"""
Install Cloudflare Tunnel as a system service
Run this after the application is deployed
"""

import subprocess
import sys
import os
from pathlib import Path

def run_command(cmd, shell=False, check=True, capture_output=False):
    """Run a shell command and return result"""
    if shell:
        print(f"Running: {cmd}")
        result = subprocess.run(cmd, shell=True, check=check, capture_output=capture_output, text=True)
    else:
        print(f"Running: {' '.join(cmd)}")
        result = subprocess.run(cmd, check=check, capture_output=capture_output, text=True)

    if capture_output:
        return result.stdout.strip(), result.returncode
    return result.returncode == 0

def check_cloudflared_installed():
    """Check if cloudflared is already installed"""
    result = subprocess.run(["which", "cloudflared"], capture_output=True, text=True)
    return result.returncode == 0

def get_env_file():
    """Get the path to the .env file"""
    script_dir = Path(__file__).parent.resolve()
    env_file = script_dir.parent.parent / ".env"
    return env_file

def read_env_var(env_file, var_name):
    """Read an environment variable from .env file"""
    if not env_file.exists():
        return None

    with open(env_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith(f"{var_name}="):
                value = line.split('=', 1)[1]
                # Remove quotes if present
                value = value.strip('"').strip("'")
                return value
    return None

def main():
    print("=" * 60)
    print("Installing Cloudflare Tunnel as System Service")
    print("=" * 60)
    print()

    # Get tunnel token from .env file
    env_file = get_env_file()
    print(f"Looking for .env file: {env_file}")

    tunnel_token = read_env_var(env_file, "CLOUDFLARED_TUNNEL_TOKEN")

    if not tunnel_token:
        print("\n" + "=" * 60)
        print("⚠ No Cloudflare tunnel token found")
        print("=" * 60)
        print(f"\nTo enable Cloudflare tunnel:")
        print(f"1. Add CLOUDFLARED_TUNNEL_TOKEN to: {env_file}")
        print(f"2. Re-run this script")
        print()
        return 1

    print("✓ Found tunnel token in .env file\n")

    # Check if cloudflared is already installed
    if check_cloudflared_installed():
        print("✓ cloudflared is already installed")
        response = input("\nDo you want to reinstall? (y/N): ").strip().lower()
        if response != 'y':
            print("Skipping installation, proceeding to service setup...")
        else:
            # Uninstall existing service
            print("\nUninstalling existing cloudflared service...")
            run_command("sudo cloudflared service uninstall", shell=True, check=False)
    else:
        print("Step 1: Installing cloudflared via apt...")
        print("-" * 60)

        # Add Cloudflare GPG key
        print("\n1.1: Adding Cloudflare GPG key...")
        if not run_command("sudo mkdir -p --mode=0755 /usr/share/keyrings", shell=True, check=False):
            print("WARNING: Failed to create keyrings directory (may already exist)")

        gpg_cmd = "curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | sudo tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null"
        if not run_command(gpg_cmd, shell=True):
            print("ERROR: Failed to add Cloudflare GPG key")
            return 1
        print("✓ GPG key added")

        # Add apt repository
        print("\n1.2: Adding Cloudflare apt repository...")
        repo_cmd = "echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list"
        if not run_command(repo_cmd, shell=True):
            print("ERROR: Failed to add apt repository")
            return 1
        print("✓ Repository added")

        # Update and install
        print("\n1.3: Installing cloudflared...")
        if not run_command("sudo apt-get update && sudo apt-get install -y cloudflared", shell=True):
            print("ERROR: Failed to install cloudflared")
            return 1
        print("✓ cloudflared installed")

    # Install as service
    print("\n" + "=" * 60)
    print("Step 2: Installing cloudflared as system service")
    print("=" * 60)
    print()

    service_cmd = f"sudo cloudflared service install {tunnel_token}"
    if not run_command(service_cmd, shell=True, check=False):
        print("WARNING: Service installation may have failed")
        print("This might be normal if the service already exists")

    print("\n✓ Service installation complete!")

    # Verify installation
    print("\n" + "=" * 60)
    print("Verification")
    print("=" * 60)
    print()

    print("Checking cloudflared version...")
    run_command("cloudflared --version", shell=True, check=False)

    print("\nChecking service status...")
    run_command("sudo systemctl status cloudflared", shell=True, check=False)

    print("\n" + "=" * 60)
    print("✓ Cloudflare tunnel setup complete!")
    print("=" * 60)

    print("\nUseful commands:")
    print("  Check status:  sudo systemctl status cloudflared")
    print("  View logs:     sudo journalctl -u cloudflared -f")
    print("  Stop service:  sudo systemctl stop cloudflared")
    print("  Start service: sudo systemctl start cloudflared")
    print("  Restart:       sudo systemctl restart cloudflared")
    print("  Uninstall:     sudo cloudflared service uninstall")
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
        import traceback
        traceback.print_exc()
        sys.exit(1)