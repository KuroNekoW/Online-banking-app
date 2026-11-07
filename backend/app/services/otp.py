import secrets
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import hash_password, verify_password
from app.db.models import OtpChallenge, OtpPurpose, OtpStatus, RegistrationRequest, Transfer, User
from app.services.otp_delivery import deliver_otp


def mask_destination(value: str) -> str:
    return ("*" * max(0, len(value) - 4)) + value[-4:]


def create_otp(db: Session, purpose: OtpPurpose, destination: str, *, user_id=None, registration_request_id=None, transfer_id=None) -> OtpChallenge:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    code = f"{secrets.randbelow(1_000_000):06d}"
    challenge = OtpChallenge(
        purpose=purpose,
        status=OtpStatus.sent,
        user_id=user_id,
        registration_request_id=registration_request_id,
        transfer_id=transfer_id,
        delivery_channel="email",
        destination_masked=mask_destination(destination),
        code_hash=hash_password(code),
        max_attempts=settings.otp_max_attempts,
        send_count=1,
        next_resend_at=now + timedelta(seconds=settings.otp_resend_cooldown_seconds),
        expires_at=now + timedelta(minutes=settings.otp_expiry_minutes),
    )
    db.add(challenge)
    db.flush()
    deliver_otp(destination, code)
    return challenge


def verify_otp(db: Session, challenge_id, code: str, purpose: OtpPurpose) -> OtpChallenge:
    challenge = db.get(OtpChallenge, challenge_id)
    invalid = HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired OTP challenge")
    if challenge is None or challenge.purpose != purpose or challenge.status not in (OtpStatus.sent, OtpStatus.verified):
        raise invalid
    now = datetime.now(timezone.utc)
    if challenge.expires_at <= now:
        challenge.status = OtpStatus.expired
        db.commit()
        raise invalid
    if challenge.status == OtpStatus.verified:
        return challenge
    if not verify_password(code, challenge.code_hash):
        challenge.attempt_count += 1
        if challenge.attempt_count >= challenge.max_attempts:
            challenge.status = OtpStatus.rejected
        db.commit()
        raise invalid
    challenge.status = OtpStatus.verified
    challenge.verified_at = now
    db.flush()
    return challenge


def resend_otp(db: Session, challenge: OtpChallenge) -> OtpChallenge:
    """Rotate an existing challenge, preserving its subject and resend limits."""
    now = datetime.now(timezone.utc)
    if challenge.status != OtpStatus.sent or challenge.expires_at <= now:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="OTP challenge cannot be resent")
    if challenge.send_count >= challenge.max_sends:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="OTP resend limit reached")
    if challenge.next_resend_at and challenge.next_resend_at > now:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Please wait before requesting another code")

    if challenge.registration_request_id:
        subject = db.get(RegistrationRequest, challenge.registration_request_id)
        destination = subject.email if subject else None
    elif challenge.user_id:
        subject = db.get(User, challenge.user_id)
        destination = subject.email if subject else None
    elif challenge.transfer_id:
        transfer = db.get(Transfer, challenge.transfer_id)
        subject = db.get(User, transfer.customer_id) if transfer else None
        destination = subject.email if subject else None
    else:
        destination = None
    if not destination:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="OTP destination is unavailable")

    settings = get_settings()
    code = f"{secrets.randbelow(1_000_000):06d}"
    challenge.code_hash = hash_password(code)
    challenge.attempt_count = 0
    challenge.send_count += 1
    challenge.expires_at = now + timedelta(minutes=settings.otp_expiry_minutes)
    challenge.next_resend_at = now + timedelta(seconds=settings.otp_resend_cooldown_seconds)
    deliver_otp(destination, code)
    db.flush()
    return challenge
