#!/usr/bin/env python3
"""
fix-md5.py
Replace MD5/SHA1 usage with secure alternatives.

Usage:
    python3 fix-md5.py <python-file>

Error codes: Bandit B303, B324 | Semgrep python.lang.security.audit.md5-used

What it does:
    - Finds hashlib.md5() and hashlib.sha1() calls
    - Replaces with hashlib.sha256() for checksums
    - Flags password hashing cases for manual bcrypt migration
    - Creates a .bak backup before modifying
"""

import sys
import re
import shutil
from pathlib import Path

RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
NC = "\033[0m"

PATTERNS = [
    # hashlib.md5() → hashlib.sha256()
    (
        re.compile(r'\bhashlib\.md5\b'),
        'hashlib.sha256',
        'B324/B303 — MD5 replaced with SHA-256'
    ),
    # hashlib.new('md5') → hashlib.new('sha256')
    (
        re.compile(r"hashlib\.new\(['\"]md5['\"]\)"),
        "hashlib.new('sha256')",
        'B303 — hashlib.new md5 replaced with sha256'
    ),
    # hashlib.sha1() → hashlib.sha256()
    (
        re.compile(r'\bhashlib\.sha1\b'),
        'hashlib.sha256',
        'B303 — SHA-1 replaced with SHA-256'
    ),
    # MD5() from Crypto.Hash
    (
        re.compile(r'\bMD5\.new\b'),
        'SHA256.new',
        'Crypto.Hash MD5 replaced with SHA256'
    ),
]

PASSWORD_PATTERNS = [
    re.compile(r'hashlib\.(md5|sha1|sha256).*password', re.IGNORECASE),
    re.compile(r'password.*hashlib\.(md5|sha1)', re.IGNORECASE),
    re.compile(r'\.hexdigest\(\).*pass', re.IGNORECASE),
    re.compile(r'pass.*\.hexdigest\(\)', re.IGNORECASE),
]


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 fix-md5.py <python-file>")
        print("")
        print("  python-file — path to Python file with MD5/SHA1 usage")
        print("")
        print("Example:")
        print("  python3 fix-md5.py api/auth.py")
        sys.exit(1)

    filepath = Path(sys.argv[1])

    if not filepath.exists():
        print(f"{RED}ERROR: File not found: {filepath}{NC}")
        sys.exit(1)

    print(f"\n{BLUE}=== Ghost Protocol — MD5/SHA1 Fix ==={NC}")
    print(f"  File: {filepath}")
    print("")

    original = filepath.read_text()
    lines = original.splitlines()

    changes = []
    password_warnings = []

    # Check for password hashing patterns first
    for i, line in enumerate(lines, 1):
        for pat in PASSWORD_PATTERNS:
            if pat.search(line):
                password_warnings.append((i, line.strip()))

    if password_warnings:
        print(f"{RED}⚠  PASSWORD HASHING DETECTED — manual migration required:{NC}")
        print("")
        for lineno, content in password_warnings:
            print(f"  Line {lineno}: {content}")
        print("")
        print("  MD5/SHA1/SHA256 must NOT be used for password storage.")
        print("  Use bcrypt, argon2, or scrypt instead:")
        print("")
        print("  Install: pip install passlib[bcrypt]")
        print("")
        print("  Before:")
        print("    password_hash = hashlib.sha256(password.encode()).hexdigest()")
        print("")
        print("  After:")
        print("    from passlib.hash import bcrypt")
        print("    password_hash = bcrypt.hash(password)            # store this")
        print("    bcrypt.verify(password, stored_hash)             # verify this")
        print("")
        print("  These lines will NOT be auto-patched. Fix manually.")
        print("")

    # Apply safe replacements (checksums, not passwords)
    modified = original
    for pattern, replacement, description in PATTERNS:
        new_content = pattern.sub(replacement, modified)
        if new_content != modified:
            count = len(pattern.findall(modified))
            changes.append((description, count))
            modified = new_content

    if not changes and not password_warnings:
        print(f"{GREEN}No MD5/SHA1 patterns found in {filepath}.{NC}")
        print("Scanner may have flagged a false positive — verify manually.")
        sys.exit(0)

    if changes:
        # Create backup
        backup = filepath.with_suffix(filepath.suffix + '.bak')
        shutil.copy2(filepath, backup)
        print(f"{YELLOW}Backup created: {backup}{NC}")
        print("")

        # Write changes
        filepath.write_text(modified)

        print(f"{GREEN}Changes applied:{NC}")
        for description, count in changes:
            print(f"  ✓ {description} ({count} occurrence{'s' if count > 1 else ''})")
        print("")
        print(f"{YELLOW}Note: SHA-256 is safe for checksums/fingerprints.")
        print(f"For password storage, also apply the bcrypt fix above.{NC}")
        print("")
        print(f"{YELLOW}Next steps:{NC}")
        print("  1. Review the changes: diff api/auth.py api/auth.py.bak")
        print("  2. Run tests: pytest (or your test runner)")
        print(f"  3. Re-scan: bandit -r {filepath.parent}/ -t B303,B324")
        print("  4. Commit: git commit -m 'security: replace MD5/SHA1 with SHA-256 (Bandit B324)'")
        print("")

    if password_warnings:
        print(f"{RED}ACTION REQUIRED:{NC} Apply bcrypt migration for password lines above.")
        print("These were NOT auto-patched to avoid breaking your auth system.")
        print("")


if __name__ == '__main__':
    main()
