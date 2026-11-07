"""Create initial mobile banking schema.

Revision ID: 20261107_0001
Revises:
Create Date: 2026-11-07
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "20261107_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE SCHEMA IF NOT EXISTS banking")
    account_status = postgresql.ENUM("active", "frozen", "closed", name="account_status", schema="banking", create_type=False)
    transaction_status = postgresql.ENUM("pending", "posted", "reversed", "failed", name="transaction_status", schema="banking", create_type=False)
    account_status.create(op.get_bind(), checkfirst=True)
    transaction_status.create(op.get_bind(), checkfirst=True)

    op.create_table("users", sa.Column("id", sa.UUID(), primary_key=True), sa.Column("email", sa.String(320), nullable=False, unique=True), sa.Column("phone", sa.String(32), unique=True), sa.Column("password_hash", sa.String(255), nullable=False), sa.Column("full_name", sa.String(150), nullable=False), sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")), schema="banking")
    op.create_table("accounts", sa.Column("id", sa.UUID(), primary_key=True), sa.Column("owner_id", sa.UUID(), sa.ForeignKey("banking.users.id"), nullable=False), sa.Column("account_number", sa.String(20), nullable=False), sa.Column("currency", sa.String(3), nullable=False, server_default="VND"), sa.Column("status", account_status, nullable=False, server_default="active"), sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")), sa.UniqueConstraint("account_number"), schema="banking")
    op.create_index("ix_accounts_owner_id", "accounts", ["owner_id"], schema="banking")
    op.create_table("transactions", sa.Column("id", sa.UUID(), primary_key=True), sa.Column("idempotency_key", sa.UUID(), nullable=False), sa.Column("reference", sa.String(64), nullable=False), sa.Column("status", transaction_status, nullable=False, server_default="pending"), sa.Column("description", sa.Text()), sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")), sa.Column("posted_at", sa.DateTime(timezone=True)), sa.UniqueConstraint("idempotency_key"), sa.UniqueConstraint("reference"), schema="banking")
    op.create_table("transaction_entries", sa.Column("id", sa.UUID(), primary_key=True), sa.Column("transaction_id", sa.UUID(), sa.ForeignKey("banking.transactions.id"), nullable=False), sa.Column("account_id", sa.UUID(), sa.ForeignKey("banking.accounts.id"), nullable=False), sa.Column("amount", sa.Numeric(19, 4), nullable=False), sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")), sa.CheckConstraint("amount <> 0", name="ck_transaction_entry_nonzero"), sa.UniqueConstraint("transaction_id", "account_id", name="uq_transaction_account_entry"), schema="banking")
    op.create_index("ix_transaction_entries_transaction_id", "transaction_entries", ["transaction_id"], schema="banking")
    op.create_index("ix_transaction_entries_account_id", "transaction_entries", ["account_id"], schema="banking")

    # Deferred constraint permits inserting both sides in one transaction, then rejects unbalanced postings at COMMIT.
    op.execute("""
        CREATE FUNCTION banking.ensure_posted_transaction_balances() RETURNS trigger AS $$
        DECLARE affected_transaction uuid;
        BEGIN
          IF TG_TABLE_NAME = 'transactions' THEN
            IF TG_OP = 'DELETE' THEN
              affected_transaction := OLD.id;
            ELSE
              affected_transaction := NEW.id;
            END IF;
          ELSE
            IF TG_OP = 'DELETE' THEN
              affected_transaction := OLD.transaction_id;
            ELSE
              affected_transaction := NEW.transaction_id;
            END IF;
          END IF;
          IF EXISTS (SELECT 1 FROM banking.transactions WHERE id = affected_transaction AND status = 'posted')
             AND COALESCE((SELECT SUM(amount) FROM banking.transaction_entries WHERE transaction_id = affected_transaction), 0) <> 0 THEN
            RAISE EXCEPTION 'Posted transaction % must balance to zero', affected_transaction;
          END IF;
          RETURN NULL;
        END;
        $$ LANGUAGE plpgsql;
        CREATE CONSTRAINT TRIGGER transaction_entries_must_balance
          AFTER INSERT OR UPDATE OR DELETE ON banking.transaction_entries
          DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION banking.ensure_posted_transaction_balances();
        CREATE CONSTRAINT TRIGGER posted_transactions_must_balance
          AFTER INSERT OR UPDATE OF status ON banking.transactions
          DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION banking.ensure_posted_transaction_balances();
        CREATE FUNCTION banking.prevent_posted_entry_mutation() RETURNS trigger AS $$
        DECLARE entry_transaction uuid;
        BEGIN
          IF TG_OP = 'DELETE' THEN
            entry_transaction := OLD.transaction_id;
          ELSE
            entry_transaction := NEW.transaction_id;
          END IF;
          IF EXISTS (SELECT 1 FROM banking.transactions WHERE id = entry_transaction AND status = 'posted') THEN
            RAISE EXCEPTION 'Entries belonging to a posted transaction are immutable';
          END IF;
          IF TG_OP = 'DELETE' THEN
            RETURN OLD;
          END IF;
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
        CREATE TRIGGER posted_entries_are_immutable
          BEFORE INSERT OR UPDATE OR DELETE ON banking.transaction_entries
          FOR EACH ROW EXECUTE FUNCTION banking.prevent_posted_entry_mutation();
    """)


def downgrade() -> None:
    op.execute("DROP FUNCTION IF EXISTS banking.ensure_posted_transaction_balances() CASCADE")
    op.execute("DROP FUNCTION IF EXISTS banking.prevent_posted_entry_mutation() CASCADE")
    op.drop_table("transaction_entries", schema="banking")
    op.drop_table("transactions", schema="banking")
    op.drop_table("accounts", schema="banking")
    op.drop_table("users", schema="banking")
    postgresql.ENUM(name="transaction_status", schema="banking").drop(op.get_bind(), checkfirst=True)
    postgresql.ENUM(name="account_status", schema="banking").drop(op.get_bind(), checkfirst=True)
    op.execute("DROP SCHEMA IF EXISTS banking")
