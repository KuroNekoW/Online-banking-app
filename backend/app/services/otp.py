import secrets
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import hash_password, verify_password
from app.db.models import OtpChallenge, OtpPurpose, OtpStatus
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
