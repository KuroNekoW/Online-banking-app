from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload

from app.api.deps import bearer_scheme, get_current_user
from app.core.config import get_settings
from app.core.security import create_access_token, decode_access_token, hash_token, new_refresh_secret, verify_password
from app.db.models import AuthSession, User, UserStatus
from app.db.session import get_db
from app.schemas.auth import CurrentUserResponse, LoginRequest, RefreshRequest, TokenResponse

router = APIRouter(prefix="/auth", tags=["auth"])


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
