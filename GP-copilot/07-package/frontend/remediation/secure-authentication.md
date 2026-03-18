# Secure Authentication — FedRAMP IA-2

## The Problem

FedRAMP requires multi-factor authentication for all users accessing the system.
Single-factor login (username + password only) is a **FedRAMP blocker**.

## What 3PAO Auditors Check

1. MFA is enforced (not optional) for all user accounts
2. Session tokens are cryptographically random with expiration
3. Failed login attempts trigger lockout
4. Password policy meets NIST 800-63B (12+ chars, breach-list check, no rotation forcing)

## Fix: Add MFA to Your Login Flow

### Option 1: TOTP (Time-Based One-Time Password)

**Python (Flask/Django):**

```python
import pyotp
import secrets

# Generate TOTP secret for user (store encrypted in DB)
def generate_mfa_secret():
    return pyotp.random_base32()

# Verify TOTP code during login
def verify_mfa(user_secret, code):
    totp = pyotp.TOTP(user_secret)
    return totp.verify(code, valid_window=1)
```

**Dependency:** `pyotp==2.9.0` (pure Python, no C deps, MIT license)

### Option 2: WebAuthn (Hardware Key / Passkey)

```python
# pip install py_webauthn==2.1.0
from webauthn import generate_registration_options, verify_registration_response
```

### Option 3: OAuth2/OIDC (Delegate to IdP)

If the client uses Okta, Azure AD, or AWS Cognito — delegate MFA to the IdP.
The application just validates the OIDC token.

```python
# Validate JWT from IdP
import jwt  # PyJWT==2.9.0

def validate_id_token(token, jwks_url, audience):
    jwks_client = jwt.PyJWKClient(jwks_url)
    signing_key = jwks_client.get_signing_key_from_jwt(token)
    return jwt.decode(
        token,
        signing_key.key,
        algorithms=["RS256"],
        audience=audience,
    )
```

## Fix: Session Management

```python
import secrets
from datetime import datetime, timedelta, timezone

SESSION_IDLE_TIMEOUT = timedelta(minutes=15)
SESSION_ABSOLUTE_TIMEOUT = timedelta(hours=8)

def create_session(user_id):
    return {
        "token": secrets.token_urlsafe(32),  # NOT random.random()
        "user_id": user_id,
        "created_at": datetime.now(tz=timezone.utc),
        "last_active": datetime.now(tz=timezone.utc),
    }

def is_session_valid(session):
    now = datetime.now(tz=timezone.utc)
    if now - session["last_active"] > SESSION_IDLE_TIMEOUT:
        return False  # Idle timeout
    if now - session["created_at"] > SESSION_ABSOLUTE_TIMEOUT:
        return False  # Absolute timeout
    return True
```

## Fix: Account Lockout

```python
MAX_FAILED_ATTEMPTS = 5
LOCKOUT_DURATION = timedelta(minutes=30)

def check_login_allowed(user):
    if user.failed_attempts >= MAX_FAILED_ATTEMPTS:
        if datetime.now(tz=timezone.utc) - user.last_failed < LOCKOUT_DURATION:
            return False  # Still locked
        user.failed_attempts = 0  # Lockout expired
    return True
```

## Fix: Password Policy (NIST 800-63B)

```python
MIN_PASSWORD_LENGTH = 12

def validate_password(password, breach_list_path=None):
    errors = []
    if len(password) < MIN_PASSWORD_LENGTH:
        errors.append(f"Password must be at least {MIN_PASSWORD_LENGTH} characters")
    # NIST 800-63B: check against known breached passwords
    if breach_list_path:
        with open(breach_list_path, "r") as f:
            if password in f.read().splitlines():
                errors.append("Password found in breach database")
    # NIST 800-63B: do NOT require special chars or forced rotation
    return errors
```

## Evidence Artifacts for 3PAO

- [ ] Screenshot: MFA enrollment flow
- [ ] Screenshot: MFA challenge during login
- [ ] Code: session token generation using `secrets` module
- [ ] Config: session timeout values (idle + absolute)
- [ ] Logs: failed login attempts with lockout triggers
- [ ] Policy doc: password requirements (NIST 800-63B compliant)

## Remediation Priority: B — Human Review

MFA implementation requires architectural decisions — human review required.
Assessment pipeline provides guidance, human approves the approach.
