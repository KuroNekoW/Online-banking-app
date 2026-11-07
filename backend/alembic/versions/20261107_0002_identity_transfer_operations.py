"""Add identity, OTP, transfer workflow, notification, and administration tables.

Revision ID: 20261107_0002
Revises: 20261107_0001
Create Date: 2026-11-07
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "20261107_0002"
down_revision = "20261107_0001"
branch_labels = None
depends_on = None


def enum(name: str, *values: str) -> sa.Enum:
    return postgresql.ENUM(*values, name=name, schema="banking", create_type=False)


def upgrade() -> None:
    user_status = enum("user_status", "pending_verification", "active", "locked", "disabled")
    transfer_type = enum("transfer_type", "internal", "interbank")
    transfer_status = enum("transfer_status", "draft", "pending_authentication", "processing", "pending_external", "completed", "failed", "cancelled")
    otp_purpose = enum("otp_purpose", "registration", "password_reset", "profile_change", "transfer_authentication", "login_mfa")
    otp_status = enum("otp_status", "created", "sent", "verified", "expired", "rejected", "consumed")
    notification_type = enum("notification_type", "transfer", "security", "account")
    for item in (user_status, transfer_type, transfer_status, otp_purpose, otp_status, notification_type):
        item.create(op.get_bind(), checkfirst=True)

    op.add_column("users", sa.Column("username", sa.String(64), nullable=True), schema="banking")
    op.add_column("users", sa.Column("status", user_status, nullable=False, server_default="pending_verification"), schema="banking")
    op.add_column("users", sa.Column("failed_login_count", sa.SmallInteger(), nullable=False, server_default="0"), schema="banking")
    op.add_column("users", sa.Column("last_login_at", sa.DateTime(timezone=True)), schema="banking")
    op.add_column("users", sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")), schema="banking")
    op.create_unique_constraint("uq_users_username", "users", ["username"], schema="banking")

    op.create_table(
        "roles",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("code", sa.String(50), nullable=False, unique=True),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("is_system", sa.Boolean(), nullable=False, server_default=sa.true()),
        schema="banking",
    )
    op.create_table(
        "permissions",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("code", sa.String(100), nullable=False, unique=True),
        sa.Column("description", sa.String(255)),
        schema="banking",
    )
    op.create_table(
        "role_permissions",
        sa.Column("role_id", sa.UUID(), sa.ForeignKey("banking.roles.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("permission_id", sa.UUID(), sa.ForeignKey("banking.permissions.id", ondelete="CASCADE"), primary_key=True),
        schema="banking",
    )
    op.create_table(
        "user_roles",
        sa.Column("user_id", sa.UUID(), sa.ForeignKey("banking.users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("role_id", sa.UUID(), sa.ForeignKey("banking.roles.id", ondelete="RESTRICT"), primary_key=True),
        sa.Column("assigned_by", sa.UUID(), sa.ForeignKey("banking.users.id", ondelete="SET NULL")),
        sa.Column("assigned_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        schema="banking",
    )

    op.create_table(
        "registration_requests",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("email", sa.String(320), nullable=False),
        sa.Column("phone", sa.String(32), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("full_name", sa.String(150), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("verified_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        schema="banking",
    )
    op.create_index("ix_registration_requests_email", "registration_requests", ["email"], schema="banking")
    op.create_index("ix_registration_requests_phone", "registration_requests", ["phone"], schema="banking")

    op.create_table(
        "auth_sessions",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("user_id", sa.UUID(), sa.ForeignKey("banking.users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("refresh_token_hash", sa.String(255), nullable=False, unique=True),
        sa.Column("device_id", sa.String(255)),
        sa.Column("user_agent", sa.String(500)),
        sa.Column("ip_address", postgresql.INET()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True)),
        sa.Column("revoke_reason", sa.String(255)),
        schema="banking",
    )
    op.create_index("ix_auth_sessions_user_active", "auth_sessions", ["user_id", "expires_at"], schema="banking")

    op.create_table(
        "beneficiaries",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("owner_id", sa.UUID(), sa.ForeignKey("banking.users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("nickname", sa.String(100), nullable=False),
        sa.Column("account_number", sa.String(34), nullable=False),
        sa.Column("account_name", sa.String(150), nullable=False),
        sa.Column("bank_code", sa.String(32)),
        sa.Column("is_internal", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint("owner_id", "account_number", "bank_code", name="uq_beneficiary_destination"),
        schema="banking",
    )
    op.create_index("ix_beneficiaries_owner_id", "beneficiaries", ["owner_id"], schema="banking")

    op.create_table(
        "transfers",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("customer_id", sa.UUID(), sa.ForeignKey("banking.users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("source_account_id", sa.UUID(), sa.ForeignKey("banking.accounts.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("destination_account_id", sa.UUID(), sa.ForeignKey("banking.accounts.id", ondelete="RESTRICT")),
        sa.Column("beneficiary_id", sa.UUID(), sa.ForeignKey("banking.beneficiaries.id", ondelete="SET NULL")),
        sa.Column("type", transfer_type, nullable=False),
        sa.Column("status", transfer_status, nullable=False, server_default="draft"),
        sa.Column("reference", sa.String(64), nullable=False, unique=True),
        sa.Column("idempotency_key", sa.UUID(), nullable=False),
        sa.Column("amount", sa.Numeric(19, 4), nullable=False),
        sa.Column("fee", sa.Numeric(19, 4), nullable=False, server_default="0"),
        sa.Column("currency", sa.String(3), nullable=False, server_default="VND"),
        sa.Column("description", sa.String(255)),
        sa.Column("external_reference", sa.String(100)),
        sa.Column("failure_code", sa.String(64)),
        sa.Column("failure_message", sa.String(255)),
        sa.Column("authenticated_at", sa.DateTime(timezone=True)),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.CheckConstraint("amount > 0", name="ck_transfer_amount_positive"),
        sa.CheckConstraint("fee >= 0", name="ck_transfer_fee_nonnegative"),
        sa.CheckConstraint("source_account_id IS DISTINCT FROM destination_account_id", name="ck_transfer_not_same_account"),
        sa.UniqueConstraint("customer_id", "idempotency_key", name="uq_transfer_customer_idempotency"),
        schema="banking",
    )
    op.create_index("ix_transfers_customer_created", "transfers", ["customer_id", "created_at"], schema="banking")
    op.create_index("ix_transfers_source_account_created", "transfers", ["source_account_id", "created_at"], schema="banking")
    op.create_index("ix_transfers_status", "transfers", ["status"], schema="banking")
    op.add_column("transactions", sa.Column("transfer_id", sa.UUID(), sa.ForeignKey("banking.transfers.id", ondelete="RESTRICT")), schema="banking")
    op.create_unique_constraint("uq_ledger_transaction_transfer", "transactions", ["transfer_id"], schema="banking")

    op.create_table(
        "otp_challenges",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("user_id", sa.UUID(), sa.ForeignKey("banking.users.id", ondelete="CASCADE")),
        sa.Column("registration_request_id", sa.UUID(), sa.ForeignKey("banking.registration_requests.id", ondelete="CASCADE")),
        sa.Column("transfer_id", sa.UUID(), sa.ForeignKey("banking.transfers.id", ondelete="CASCADE")),
        sa.Column("purpose", otp_purpose, nullable=False),
        sa.Column("status", otp_status, nullable=False, server_default="created"),
        sa.Column("delivery_channel", sa.String(16), nullable=False),
        sa.Column("destination_masked", sa.String(320), nullable=False),
        sa.Column("code_hash", sa.String(255), nullable=False),
        sa.Column("attempt_count", sa.SmallInteger(), nullable=False, server_default="0"),
        sa.Column("max_attempts", sa.SmallInteger(), nullable=False, server_default="5"),
        sa.Column("send_count", sa.SmallInteger(), nullable=False, server_default="0"),
        sa.Column("max_sends", sa.SmallInteger(), nullable=False, server_default="3"),
        sa.Column("next_resend_at", sa.DateTime(timezone=True)),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("verified_at", sa.DateTime(timezone=True)),
        sa.Column("consumed_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.CheckConstraint("attempt_count >= 0 AND attempt_count <= max_attempts", name="ck_otp_attempt_range"),
        sa.CheckConstraint("send_count >= 0 AND send_count <= max_sends", name="ck_otp_send_range"),
        sa.CheckConstraint("num_nonnulls(user_id, registration_request_id) = 1", name="ck_otp_single_identity_subject"),
        schema="banking",
    )
    op.create_index("ix_otp_challenges_transfer_id", "otp_challenges", ["transfer_id"], schema="banking")
    op.create_index("ix_otp_challenges_user_purpose", "otp_challenges", ["user_id", "purpose", "expires_at"], schema="banking")

    op.create_table(
        "notifications",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("user_id", sa.UUID(), sa.ForeignKey("banking.users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("transfer_id", sa.UUID(), sa.ForeignKey("banking.transfers.id", ondelete="SET NULL")),
        sa.Column("type", notification_type, nullable=False),
        sa.Column("title", sa.String(150), nullable=False),
        sa.Column("body", sa.String(500), nullable=False),
        sa.Column("read_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        schema="banking",
    )
    op.create_index("ix_notifications_user_created", "notifications", ["user_id", "created_at"], schema="banking")

    op.create_table(
        "audit_logs",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("actor_user_id", sa.UUID(), sa.ForeignKey("banking.users.id", ondelete="SET NULL")),
        sa.Column("action", sa.String(100), nullable=False),
        sa.Column("target_type", sa.String(50), nullable=False),
        sa.Column("target_id", sa.UUID()),
        sa.Column("metadata", postgresql.JSONB(), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("ip_address", postgresql.INET()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        schema="banking",
    )
    op.create_index("ix_audit_logs_target", "audit_logs", ["target_type", "target_id", "created_at"], schema="banking")


def downgrade() -> None:
    op.drop_table("audit_logs", schema="banking")
    op.drop_table("notifications", schema="banking")
    op.drop_table("otp_challenges", schema="banking")
    op.drop_constraint("uq_ledger_transaction_transfer", "transactions", schema="banking")
    op.drop_column("transactions", "transfer_id", schema="banking")
    op.drop_table("transfers", schema="banking")
    op.drop_table("beneficiaries", schema="banking")
    op.drop_table("auth_sessions", schema="banking")
    op.drop_table("registration_requests", schema="banking")
    op.drop_table("user_roles", schema="banking")
    op.drop_table("role_permissions", schema="banking")
    op.drop_table("permissions", schema="banking")
    op.drop_table("roles", schema="banking")
    op.drop_constraint("uq_users_username", "users", schema="banking")
    op.drop_column("users", "updated_at", schema="banking")
    op.drop_column("users", "last_login_at", schema="banking")
    op.drop_column("users", "failed_login_count", schema="banking")
    op.drop_column("users", "status", schema="banking")
    op.drop_column("users", "username", schema="banking")
    for name in ("notification_type", "otp_status", "otp_purpose", "transfer_status", "transfer_type", "user_status"):
        postgresql.ENUM(name=name, schema="banking").drop(op.get_bind(), checkfirst=True)
