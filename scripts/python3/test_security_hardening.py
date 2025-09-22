#!/usr/bin/env python3
"""
Security Hardening Validation Script
Tests the implemented security controls for Portfolio platform
"""

import sys
import yaml
from pathlib import Path


def test_kubernetes_security():
    """Test Kubernetes security configurations"""
    print("🔒 Testing Kubernetes Security Hardening")
    print("=" * 50)

    tests_passed = 0
    total_tests = 0

    # Test 1: Check if network policies are enabled
    total_tests += 1
    values_path = Path("charts/portfolio/values.yaml")
    if values_path.exists():
        with open(values_path) as f:
            values = yaml.safe_load(f)

        if values.get("networkPolicy", {}).get("enabled", False):
            print("✅ Network policies are enabled")
            tests_passed += 1
        else:
            print("❌ Network policies are not enabled")
    else:
        print("❌ Values.yaml not found")

    # Test 2: Check security context configuration
    total_tests += 1
    security_context = values.get("containerSecurityContext", {})
    required_security = {
        "runAsNonRoot": True,
        "allowPrivilegeEscalation": False,
        "privileged": False,
    }

    security_ok = all(
        security_context.get(key) == value for key, value in required_security.items()
    )

    if security_ok:
        print("✅ Container security context properly configured")
        tests_passed += 1
    else:
        print("❌ Container security context missing required settings")

    # Test 3: Check capabilities are dropped
    total_tests += 1
    caps = security_context.get("capabilities", {})
    if "ALL" in caps.get("drop", []) and not caps.get("add", []):
        print("✅ All capabilities dropped, none added")
        tests_passed += 1
    else:
        print("❌ Capabilities not properly configured")

    return tests_passed, total_tests


def test_docker_security():
    """Test Docker security configurations"""
    print("\n🐳 Testing Docker Security Hardening")
    print("=" * 50)

    tests_passed = 0
    total_tests = 0

    # Test 1: Check if Dockerfile uses non-root user
    total_tests += 1
    dockerfile_path = Path("api/Dockerfile")
    if dockerfile_path.exists():
        with open(dockerfile_path) as f:
            dockerfile_content = f.read()

        if "USER appuser" in dockerfile_content:
            if (
                "useradd -u 10001" in dockerfile_content
                and "-s /sbin/nologin" in dockerfile_content
            ):
                print("✅ Dockerfile uses hardened non-root user")
                tests_passed += 1
            else:
                print("⚠️ Dockerfile uses non-root user but not hardened")
        else:
            print("❌ Dockerfile doesn't use non-root user properly")
    else:
        print("❌ Dockerfile not found")

    # Test 2: Check security labels
    total_tests += 1
    if dockerfile_path.exists():
        required_labels = [
            'security.scan="enabled"',
            'security.non-root="true"',
            'security.capabilities="none"',
        ]

        labels_found = sum(
            1 for label in required_labels if label in dockerfile_content
        )
        if labels_found == len(required_labels):
            print("✅ Security labels properly configured")
            tests_passed += 1
        else:
            print(f"❌ Missing security labels ({labels_found}/{len(required_labels)})")

    return tests_passed, total_tests


def run_security_audit():
    """Run complete security audit"""
    print("🔒 PORTFOLIO PLATFORM SECURITY AUDIT")
    print("=" * 60)
    print()

    # Run security tests
    k8s_passed, k8s_total = test_kubernetes_security()
    docker_passed, docker_total = test_docker_security()

    all_tests_passed = k8s_passed + docker_passed
    all_total_tests = k8s_total + docker_total

    # Summary
    print("\n" + "=" * 60)
    print("🏆 SECURITY AUDIT SUMMARY")
    print("=" * 60)

    security_percentage = (
        (all_tests_passed / all_total_tests) * 100 if all_total_tests > 0 else 0
    )

    print(
        f"\n📊 Overall Security Score: {all_tests_passed}/{all_total_tests} ({security_percentage:.1f}%)"
    )

    # Security rating
    if security_percentage >= 90:
        rating = "🛡️ EXCELLENT - Production Ready"
        status_code = 0
    elif security_percentage >= 80:
        rating = "✅ GOOD - Minor improvements needed"
        status_code = 0
    else:
        rating = "⚠️ NEEDS IMPROVEMENT"
        status_code = 1

    print(f"\n🎖️ Security Rating: {rating}")

    return status_code


if __name__ == "__main__":
    exit_code = run_security_audit()
    sys.exit(exit_code)
