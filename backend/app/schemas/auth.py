from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


class LoginRequest(BaseModel):
    identifier: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=8, max_length=128)
    device_id: str | None = Field(default=None, max_length=255)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=40, max_length=255)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class CurrentUserResponse(BaseModel):
    id: UUID
    # Keep this as str so the documented local development admin address is valid.
    email: str
    full_name: str
    status: str
    roles: list[str]
    last_login_at: datetime | None


class RegisterRequest(BaseModel):
    email: EmailStr
    phone: str = Field(min_length=8, max_length=32)
    full_name: str = Field(min_length=2, max_length=150)
    password: str = Field(min_length=8, max_length=128)


class OtpVerifyRequest(BaseModel):
    challenge_id: UUID
    code: str = Field(pattern=r"^\d{6}$")


class ChallengeResponse(BaseModel):
    challenge_id: UUID
    expires_at: datetime
    message: str


class PasswordResetConfirmRequest(OtpVerifyRequest):
    new_password: str = Field(min_length=8, max_length=128)


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=8, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)
