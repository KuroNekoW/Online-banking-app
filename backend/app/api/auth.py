import secrets
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload

from app.api.deps import bearer_scheme, get_current_user
from app.core.config import get_settings
from app.core.security import create_access_token, decode_access_token, hash_password, hash_token, new_refresh_secret, verify_password
from app.db.models import Account, AccountStatus, AuthSession, OtpChallenge, OtpPurpose, OtpStatus, RegistrationRequest, Role, User, UserStatus
from app.db.session import get_db
from app.schemas.auth import ChallengeResponse, ChangePasswordRequest, CurrentUserResponse, LoginRequest, OtpVerifyRequest, PasswordResetConfirmRequest, RefreshRequest, RegisterRequest, TokenResponse
from app.services.otp import create_otp, resend_otp as resend_otp_challenge, verify_otp

router = APIRouter(prefix="/auth", tags=["auth"])


def challenge_response(challenge, message: str) -> ChallengeResponse:
    return ChallengeResponse(challenge_id=challenge.id, expires_at=challenge.expires_at, message=message)


@router.post("/register", response_model=ChallengeResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, db: Session = Depends(get_db)) -> ChallengeResponse:
    if db.query(User).filter(or_(User.email == payload.email, User.phone == payload.phone)).first():
        raise HTTPException(status_code=409, detail="Email or phone is already registered")
    request = RegistrationRequest(
        email=str(payload.email), phone=payload.phone, full_name=payload.full_name,
        password_hash=hash_password(payload.password),
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=15),
    )
    db.add(request)
    db.flush()
    challenge = create_otp(db, OtpPurpose.registration, str(payload.email), registration_request_id=request.id)
    db.commit()
    return challenge_response(challenge, "Verification code sent")


@router.post("/register/verify", status_code=status.HTTP_201_CREATED)
def verify_registration(payload: OtpVerifyRequest, db: Session = Depends(get_db)) -> dict:
    challenge = verify_otp(db, payload.challenge_id, payload.code, OtpPurpose.registration)
    request = db.get(RegistrationRequest, challenge.registration_request_id)
    if request is None or request.verified_at is not None or request.expires_at <= datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="Registration request is invalid or expired")
    if db.query(User).filter(or_(User.email == request.email, User.phone == request.phone)).first():
        raise HTTPException(status_code=409, detail="Email or phone is already registered")
    user = User(email=request.email, phone=request.phone, full_name=request.full_name, password_hash=request.password_hash, status=UserStatus.active)
    customer_role = db.query(Role).filter(Role.code == "CUSTOMER").first()
    if customer_role is None:
        raise HTTPException(status_code=500, detail="Customer role is not configured")
    user.roles.append(customer_role)
    db.add(user)
    db.flush()
    account = Account(owner_id=user.id, account_number=f"100{secrets.randbelow(10**12):012d}", currency="VND", status=AccountStatus.active)
    db.add(account)
    request.verified_at = datetime.now(timezone.utc)
    challenge.status, challenge.consumed_at = OtpStatus.consumed, datetime.now(timezone.utc)
    db.commit()
    return {"user_id": str(user.id), "account_id": str(account.id), "message": "Account activated"}


@router.post("/otp/{challenge_id}/resend", response_model=ChallengeResponse)
def resend_otp(challenge_id: uuid.UUID, db: Session = Depends(get_db)) -> ChallengeResponse:
    challenge = db.get(OtpChallenge, challenge_id)
    if challenge is None:
        raise HTTPException(status_code=400, detail="OTP challenge cannot be resent")
    replacement = resend_otp_challenge(db, challenge)
    db.commit()
    return challenge_response(replacement, "Verification code resent")


def issue_tokens(db: Session, user: User, request: Request) -> TokenResponse:
    settings = get_settings()
    refresh_token = new_refresh_secret()
    session = AuthSession(
        user_id=user.id,
        refresh_token_hash=hash_token(refresh_token),
        device_id=request.headers.get("x-device-id"),
        user_agent=request.headers.get("user-agent"),
        expires_at=datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_days),
    )
    db.add(session)
    db.flush()
    roles = [role.code for role in user.roles]
    return TokenResponse(
        access_token=create_access_token(user.id, session.id, roles),
        refresh_token=refresh_token,
        expires_in=settings.access_token_minutes * 60,
    )


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, request: Request, db: Session = Depends(get_db)) -> TokenResponse:
    user = (
        db.query(User)
        .options(joinedload(User.roles))
        .filter(or_(User.email == payload.identifier, User.phone == payload.identifier, User.username == payload.identifier))
        .first()
    )
    invalid_credentials = HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    if user is None or not verify_password(payload.password, user.password_hash):
        raise invalid_credentials
    if user.status != UserStatus.active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is not active")

    user.failed_login_count = 0
    user.last_login_at = datetime.now(timezone.utc)
    tokens = issue_tokens(db, user, request)
    db.commit()
    return tokens


@router.post("/refresh", response_model=TokenResponse)
def refresh(payload: RefreshRequest, request: Request, db: Session = Depends(get_db)) -> TokenResponse:
    token_hash = hash_token(payload.refresh_token)
    session = db.query(AuthSession).filter(AuthSession.refresh_token_hash == token_hash).first()
    if session is None or session.revoked_at is not None or session.expires_at <= datetime.now(timezone.utc):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token")
    user = db.query(User).options(joinedload(User.roles)).filter(User.id == session.user_id).first()
    if user is None or user.status != UserStatus.active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token")
    session.revoked_at = datetime.now(timezone.utc)
    session.revoke_reason = "rotated"
    tokens = issue_tokens(db, user, request)
    db.commit()
    return tokens


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> None:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired access token")
    try:
        session_id = decode_access_token(credentials.credentials)["sid"]
        session = db.get(AuthSession, session_id)
    except Exception:
        session = None
    if session is None or session.revoked_at is not None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired access token")
    session.revoked_at = datetime.now(timezone.utc)
    session.revoke_reason = "logout"
    db.commit()


@router.get("/me", response_model=CurrentUserResponse)
def me(current_user: User = Depends(get_current_user)) -> CurrentUserResponse:
    return CurrentUserResponse(
        id=current_user.id,
        email=current_user.email,
        full_name=current_user.full_name,
        status=current_user.status.value,
        roles=[role.code for role in current_user.roles],
        last_login_at=current_user.last_login_at,
    )


@router.post("/password-reset", response_model=ChallengeResponse)
def request_password_reset(identifier: str, db: Session = Depends(get_db)) -> ChallengeResponse:
    user = db.query(User).filter(or_(User.email == identifier, User.phone == identifier, User.username == identifier)).first()
    if user is None or user.status != UserStatus.active:
        raise HTTPException(status_code=404, detail="Active account not found")
    challenge = create_otp(db, OtpPurpose.password_reset, user.email, user_id=user.id)
    db.commit()
    return challenge_response(challenge, "Verification code sent")


@router.post("/password-reset/confirm", status_code=status.HTTP_204_NO_CONTENT)
def confirm_password_reset(payload: PasswordResetConfirmRequest, db: Session = Depends(get_db)) -> None:
    challenge = verify_otp(db, payload.challenge_id, payload.code, OtpPurpose.password_reset)
    user = db.get(User, challenge.user_id)
    if user is None:
        raise HTTPException(status_code=400, detail="Invalid password reset request")
    user.password_hash = hash_password(payload.new_password)
    challenge.status, challenge.consumed_at = OtpStatus.consumed, datetime.now(timezone.utc)
    db.query(AuthSession).filter(AuthSession.user_id == user.id, AuthSession.revoked_at.is_(None)).update({AuthSession.revoked_at: datetime.now(timezone.utc), AuthSession.revoke_reason: "password_reset"})
    db.commit()


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT)
def change_password(payload: ChangePasswordRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    if not verify_password(payload.current_password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    current_user.password_hash = hash_password(payload.new_password)
    db.query(AuthSession).filter(AuthSession.user_id == current_user.id, AuthSession.id != None, AuthSession.revoked_at.is_(None)).update({AuthSession.revoked_at: datetime.now(timezone.utc), AuthSession.revoke_reason: "password_changed"})
    db.commit()
