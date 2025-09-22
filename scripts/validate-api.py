import tempfile

#!/usr/bin/env python3
"""
Validation script to ensure clean API structure without legacy imports.
Run this before building/deploying to catch import issues early.
"""

import sys
import os
from pathlib import Path


def check_legacy_files():
    """Check that no legacy API files exist in the root"""
    legacy_files = [
        "api/routes_*.py",
        "api/engines/",
        "api/services/",
        "api/schemas.py",
        "api/settings.py",
        "api/main.py",
        "api/llm_client.py",
    ]

    found_legacy = []
    for pattern in legacy_files:
        if "*" in pattern:
            # Handle glob patterns
            from glob import glob

            matches = glob(pattern)
            if matches:
                found_legacy.extend(matches)
        else:
            if os.path.exists(pattern):
                found_legacy.append(pattern)

    if found_legacy:
        print("❌ Legacy API files still present:")
        for f in found_legacy:
            print(f"  - {f}")
        print("\nMove these files to api/_legacy/ to avoid import conflicts")
        return False

    print("✅ No legacy API files found")
    return True


def check_clean_imports():
    """Verify all imports use app.* structure"""
    api_dir = Path("api/app")
    if not api_dir.exists():
        print("❌ api/app directory not found")
        return False

    bad_imports = []

    for py_file in api_dir.rglob("*.py"):
        if py_file.name.startswith("."):
            continue

        try:
            with open(py_file, "r") as f:
                content = f.read()
                lines = content.splitlines()

            for i, line in enumerate(lines, 1):
                line = line.strip()
                if line.startswith("#") or not line:
                    continue

                # Check for legacy imports
                if (
                    ("import routes_" in line)
                    or ("from routes_" in line)
                    or ("import engines." in line)
                    or ("from engines." in line)
                    or ("import services." in line and "app.services" not in line)
                    or ("from services." in line and "app.services" not in line)
                    or ("import schemas" in line and "app.schemas" not in line)
                ):
                    bad_imports.append(f"{py_file}:{i} - {line}")
        except Exception as e:
            print(f"⚠️  Could not read {py_file}: {e}")

    if bad_imports:
        print("❌ Legacy imports found:")
        for imp in bad_imports:
            print(f"  - {imp}")
        return False

    print("✅ All imports use clean app.* structure")
    return True


def check_dockerfile():
    """Verify Dockerfile only copies app/ and assets/"""
    dockerfile_path = "api/Dockerfile"
    if not os.path.exists(dockerfile_path):
        print("❌ api/Dockerfile not found")
        return False

    with open(dockerfile_path, "r") as f:
        content = f.read()

    # Check for correct COPY statements
    if "COPY api/app/" in content and "COPY api/assets/" in content:
        print("✅ Dockerfile uses correct COPY paths")
        return True
    else:
        print("❌ Dockerfile COPY statements may be incorrect")
        print("Should contain: 'COPY api/app/' and 'COPY api/assets/'")
        return False


def test_imports():
    """Test that Python can import the app structure"""
    try:
        sys.path.insert(0, "api")
        os.environ.setdefault("DATA_DIR", tempfile.mkdtemp())
        os.environ.setdefault("PUBLIC_BASE_URL", "http://localhost:8000")

        from app.main import app
        from app.settings import settings

        print(
            f"✅ API imports successful - {settings.LLM_PROVIDER}/{settings.LLM_MODEL}"
        )
        return True
    except Exception as e:
        print(f"❌ Import test failed: {e}")
        return False


def main():
    """Run all validation checks"""
    print("🔍 Validating Portfolio API structure...")
    print()

    checks = [
        ("Legacy Files", check_legacy_files),
        ("Clean Imports", check_clean_imports),
        ("Dockerfile", check_dockerfile),
        ("Python Imports", test_imports),
    ]

    all_passed = True
    for name, check_func in checks:
        print(f"📋 {name}:")
        try:
            passed = check_func()
            if not passed:
                all_passed = False
        except Exception as e:
            print(f"❌ {name} check failed: {e}")
            all_passed = False
        print()

    if all_passed:
        print("🎉 All validation checks passed!")
        print("✅ Ready for clean deployment")
        return 0
    else:
        print("💥 Some validation checks failed")
        print("❌ Fix issues before deploying")
        return 1


if __name__ == "__main__":
    sys.exit(main())
