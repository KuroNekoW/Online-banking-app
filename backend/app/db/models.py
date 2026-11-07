import enum
import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import Boolean, Column, DateTime, Enum, ForeignKey, JSON, Numeric, SmallInteger, String, Table, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class AccountStatus(str, enum.Enum):
    active = "active"
    frozen = "frozen"
    closed = "closed"


class UserStatus(str, enum.Enum):
    pending_verification = "pending_verification"
    active = "active"
    locked = "locked"
    disabled = "disabled"


class TransactionStatus(str, enum.Enum):
    pending = "pending"
    posted = "posted"
    reversed = "reversed"
    failed = "failed"


class TransferType(str, enum.Enum):
    internal = "internal"
    interbank = "interbank"


class TransferStatus(str, enum.Enum):
    draft = "draft"
    pending_authentication = "pending_authentication"
    processing = "processing"
    pending_external = "pending_external"
    completed = "completed"
    failed = "failed"
    cancelled = "cancelled"


class OtpPurpose(str, enum.Enum):
    registration = "registration"
    password_reset = "password_reset"
    profile_change = "profile_change"
    transfer_authentication = "transfer_authentication"
    login_mfa = "login_mfa"


class OtpStatus(str, enum.Enum):
    created = "created"
    sent = "sent"
    verified = "verified"
    expired = "expired"
    rejected = "rejected"
    consumed = "consumed"


class NotificationType(str, enum.Enum):
    transfer = "transfer"
    security = "security"
    account = "account"


class User(Base):
    __tablename__ = "users"
    __table_args__ = {"schema": "banking"}

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(320), unique=True, nullable=False)
    phone: Mapped[str | None] = mapped_column(String(32), unique=True)
    username: Mapped[str | None] = mapped_column(String(64), unique=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(150), nullable=False)
    status: Mapped[UserStatus] = mapped_column(Enum(UserStatus, name="user_status", schema="banking"), nullable=False, default=UserStatus.pending_verification)
    failed_login_count: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=0)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    accounts: Mapped[list["Account"]] = relationship(back_populates="owner")
    roles: Mapped[list["Role"]] = relationship(secondary=lambda: user_roles, back_populates="users")


class Role(Base):
    __tablename__ = "roles"
    __table_args__ = {"schema": "banking"}

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    is_system: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    users: Mapped[list[User]] = relationship(secondary=lambda: user_roles, back_populates="roles")
    permissions: Mapped[list["Permission"]] = relationship(secondary=lambda: role_permissions, back_populates="roles")


class Permission(Base):
    __tablename__ = "permissions"
    __table_args__ = {"schema": "banking"}

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    description: Mapped[str | None] = mapped_column(String(255))
    roles: Mapped[list[Role]] = relationship(secondary=lambda: role_permissions, back_populates="permissions")


user_roles = Table(
    "user_roles",
    Base.metadata,
    Column("user_id", UUID(as_uuid=True), ForeignKey("banking.users.id", ondelete="CASCADE"), primary_key=True),
    Column("role_id", UUID(as_uuid=True), ForeignKey("banking.roles.id", ondelete="RESTRICT"), primary_key=True),
    schema="banking",
)

role_permissions = Table(
    "role_permissions",
    Base.metadata,
    Column("role_id", UUID(as_uuid=True), ForeignKey("banking.roles.id", ondelete="CASCADE"), primary_key=True),
    Column("permission_id", UUID(as_uuid=True), ForeignKey("banking.permissions.id", ondelete="CASCADE"), primary_key=True),
    schema="banking",
)


class AuthSession(Base):
    __tablename__ = "auth_sessions"
    __table_args__ = {"schema": "banking"}

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("banking.users.id", ondelete="CASCADE"), nullable=False, index=True)
    refresh_token_hash: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    device_id: Mapped[str | None] = mapped_column(String(255))
    user_agent: Mapped[str | None] = mapped_column(String(500))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    revoke_reason: Mapped[str | None] = mapped_column(String(255))


class Account(Base):
    __tablename__ = "accounts"
    __table_args__ = (UniqueConstraint("account_number"), {"schema": "banking"})

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("banking.users.id"), nullable=False, index=True)
    account_number: Mapped[str] = mapped_column(String(20), nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="VND")
    status: Mapped[AccountStatus] = mapped_column(Enum(AccountStatus, name="account_status", schema="banking"), nullable=False, default=AccountStatus.active)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    owner: Mapped[User] = relationship(back_populates="accounts")


class Transaction(Base):
    __tablename__ = "transactions"
    __table_args__ = (UniqueConstraint("idempotency_key"), {"schema": "banking"})

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    idempotency_key: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    reference: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    status: Mapped[TransactionStatus] = mapped_column(Enum(TransactionStatus, name="transaction_status", schema="banking"), nullable=False, default=TransactionStatus.pending)
    description: Mapped[str | None] = mapped_column(Text)
    transfer_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("banking.transfers.id", ondelete="RESTRICT"), unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    posted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    entries: Mapped[list["TransactionEntry"]] = relationship(back_populates="transaction")


class TransactionEntry(Base):
    __tablename__ = "transaction_entries"
    __table_args__ = (UniqueConstraint("transaction_id", "account_id", name="uq_transaction_account_entry"), {"schema": "banking"})

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    transaction_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("banking.transactions.id"), nullable=False, index=True)
    account_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("banking.accounts.id"), nullable=False, index=True)
    # Signed amount: positive credits an account, negative debits it. Never mutate posted entries.
    amount: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    transaction: Mapped[Transaction] = relationship(back_populates="entries")


class RegistrationRequest(Base):
    __tablename__ = "registration_requests"
    __table_args__ = {"schema": "banking"}
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(320), nullable=False)
    phone: Mapped[str] = mapped_column(String(32), nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(150), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class Beneficiary(Base):
    __tablename__ = "beneficiaries"
    __table_args__ = {"schema": "banking"}
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("banking.users.id", ondelete="CASCADE"), nullable=False, index=True)
    nickname: Mapped[str] = mapped_column(String(100), nullable=False)
    account_number: Mapped[str] = mapped_column(String(34), nullable=False)
    account_name: Mapped[str] = mapped_column(String(150), nullable=False)
    bank_code: Mapped[str | None] = mapped_column(String(32))
    is_internal: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)


class Transfer(Base):
    __tablename__ = "transfers"
    __table_args__ = {"schema": "banking"}
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    customer_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("banking.users.id"), nullable=False, index=True)
    source_account_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("banking.accounts.id"), nullable=False)
    destination_account_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("banking.accounts.id"))
    beneficiary_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("banking.beneficiaries.id"))
    type: Mapped[TransferType] = mapped_column(Enum(TransferType, name="transfer_type", schema="banking"), nullable=False)
    status: Mapped[TransferStatus] = mapped_column(Enum(TransferStatus, name="transfer_status", schema="banking"), nullable=False, default=TransferStatus.draft)
    reference: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    idempotency_key: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    fee: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False, default=Decimal("0"))
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="VND")
    description: Mapped[str | None] = mapped_column(String(255))
    external_reference: Mapped[str | None] = mapped_column(String(100))
    failure_code: Mapped[str | None] = mapped_column(String(64))
    failure_message: Mapped[str | None] = mapped_column(String(255))
    authenticated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)


class OtpChallenge(Base):
    __tablename__ = "otp_challenges"
    __table_args__ = {"schema": "banking"}
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("banking.users.id", ondelete="CASCADE"))
    registration_request_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("banking.registration_requests.id", ondelete="CASCADE"))
    transfer_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("banking.transfers.id", ondelete="CASCADE"))
    purpose: Mapped[OtpPurpose] = mapped_column(Enum(OtpPurpose, name="otp_purpose", schema="banking"), nullable=False)
    status: Mapped[OtpStatus] = mapped_column(Enum(OtpStatus, name="otp_status", schema="banking"), nullable=False, default=OtpStatus.created)
    delivery_channel: Mapped[str] = mapped_column(String(16), nullable=False)
    destination_masked: Mapped[str] = mapped_column(String(320), nullable=False)
    code_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    attempt_count: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=0)
    max_attempts: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=5)
    send_count: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=1)
    max_sends: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=3)
    next_resend_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class Notification(Base):
    __tablename__ = "notifications"
    __table_args__ = {"schema": "banking"}
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("banking.users.id", ondelete="CASCADE"), nullable=False)
    transfer_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("banking.transfers.id", ondelete="SET NULL"))
    type: Mapped[NotificationType] = mapped_column(Enum(NotificationType, name="notification_type", schema="banking"), nullable=False)
    title: Mapped[str] = mapped_column(String(150), nullable=False)
    body: Mapped[str] = mapped_column(String(500), nullable=False)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class AuditLog(Base):
    __tablename__ = "audit_logs"
    __table_args__ = {"schema": "banking"}
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("banking.users.id", ondelete="SET NULL"))
    action: Mapped[str] = mapped_column(String(100), nullable=False)
    target_type: Mapped[str] = mapped_column(String(50), nullable=False)
    target_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True))
    metadata_: Mapped[dict] = mapped_column("metadata", JSON, nullable=False, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
