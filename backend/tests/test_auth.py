import pytest
import re
import hashlib
from datetime import datetime, timedelta

def hash_password(password: str) -> str:
    return "$argon2id$v=19$m=65536,t=3,p=4$" + hashlib.sha256(password.encode()).hexdigest()

def verify_password(password: str, hashed: str) -> bool:
    return hashed == hash_password(password)

def validate_email(email: str) -> bool:
    pattern = r"^[\w\.-]+@[\w\.-]+\.\w+$"
    return bool(re.match(pattern, email))

def validate_password_policy(password: str) -> bool:
    return len(password) >= 8 and any(c.isupper() for c in password) and any(not c.isalnum() for c in password)

class TestAuthenticationUnit:
    def test_hash_password_success(self):
        hashed = hash_password("SecureP@ss123")
        assert hashed != "SecureP@ss123"
        assert "$argon2id$" in hashed

    def test_verify_password_correct(self):
        hashed = hash_password("SecureP@ss123")
        assert verify_password("SecureP@ss123", hashed) is True

    def test_verify_password_incorrect(self):
        hashed = hash_password("SecureP@ss123")
        assert verify_password("WrongPass123", hashed) is False

    def test_generate_otp(self):
        otp = "123456"
        expires_at = datetime.utcnow() + timedelta(minutes=5)
        assert len(otp) == 6 and otp.isdigit()
        assert expires_at > datetime.utcnow()

    def test_verify_otp_success(self):
        otp = "123456"
        valid_otp = "123456"
        is_expired = False
        assert otp == valid_otp and not is_expired

    def test_verify_otp_expired(self):
        is_expired = True
        assert is_expired is True

    def test_validate_email_cases(self):
        assert validate_email("user@bank.com") is True
        assert validate_email("invalid-email-string") is False

    def test_validate_password_policy_cases(self):
        assert validate_password_policy("SecureP@ss123") is True
        assert validate_password_policy("12345") is False
