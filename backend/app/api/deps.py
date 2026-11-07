import uuid
from collections.abc import Callable

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session, joinedload

from app.core.security import decode_access_token
from app.db.models import AuthSession, User, UserStatus
from app.db.session import get_db

bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    unauthorized = HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired access token", headers={"WWW-Authenticate": "Bearer"})
    if credentials is None:
        raise unauthorized
    try:
        payload = decode_access_token(credentials.credentials)
        user_id = uuid.UUID(payload["sub"])
        session_id = uuid.UUID(payload["sid"])
    except (KeyError, ValueError, jwt.PyJWTError):
        raise unauthorized

    session = db.get(AuthSession, session_id)
    user = db.query(User).options(joinedload(User.roles)).filter(User.id == user_id).first()
    if session is None or session.user_id != user_id or session.revoked_at is not None or user is None or user.status != UserStatus.active:
        raise unauthorized
    return user


def get_current_admin(current_user: User = Depends(get_current_user)) -> User:
    if "ADMIN" not in {role.code for role in current_user.roles}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Administrator permission required")
    return current_user
