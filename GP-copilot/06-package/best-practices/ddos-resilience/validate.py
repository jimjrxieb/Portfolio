#!/usr/bin/env python3
"""
DDoS Resilience Pattern - Validation
Checks if CloudFront + WAF + Shield are actually deployed
"""

import sys
from pathlib import Path

# Add parent to path
sys.path.append(str(Path(__file__).parent.parent))
from cloud_patterns_scanner import CloudPatternsScanner


def main():
    """Validate DDoS Resilience pattern only"""
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║         DDoS RESILIENCE PATTERN - VALIDATION                ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print()

    project_root = Path(__file__).parent.parent.parent.parent
    output_dir = project_root / 'secops' / '2-findings' / 'raw'

    scanner = CloudPatternsScanner(
        scan_target=project_root,
        output_dir=output_dir,
        use_localstack=True
    )

    # Run only DDoS resilience validation
    result = scanner.validate_ddos_resilience()

    print(f"Pattern: {result['pattern']}")
    print(f"Description: {result['description']}")
    print(f"Status: {result['status']}")
    print()

    if result['issues']:
        print(f"Issues Found: {result['issue_count']}")
        print()
        for i, issue in enumerate(result['issues'], 1):
            print(f"{i}. [{issue['severity']}] {issue['message']}")
            print(f"   Check: {issue['check']}")
            print(f"   Remediation: {issue['remediation']}")
            if 'compliance' in issue:
                print(f"   Compliance: {', '.join(issue['compliance'])}")
            if 'cost_impact' in issue:
                print(f"   Cost: {issue['cost_impact']}")
            print()
    else:
        print("✅ All checks passed - pattern properly implemented")

    print("="*60)
    print(f"Result: {'FAIL' if result['issues'] else 'PASS'}")
    print("="*60)

    return 0 if result['status'] == 'PASS' else 1


if __name__ == '__main__':
    sys.exit(main())
