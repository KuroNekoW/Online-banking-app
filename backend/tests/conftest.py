import os
from decimal import Decimal
from uuid import uuid4

# Set this before importing app modules, which create their database engine at import time.
os.environ["DATABASE_URL"] = os.getenv(
    "TEST_DATABASE_URL",
    "postgresql+psycopg://banking_test:banking_test_password@localhost:5433/banking_test",
)
os.environ["JWT_SECRET_KEY"] = "test-only-secret-key-at-least-32-characters"

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import text

from app.api.deps import get_db
from app.core.config import get_settings

get_settings.cache_clear()
from app.core.security import hash_password
from app.db.models import Account, AccountStatus, Role, Transaction, TransactionEntry, TransactionStatus, User, UserStatus
from app.db.session import SessionLocal, engine
from app.scripts.seed import seed
from main import app


@pytest.fixture(scope="session", autouse=True)
def migrated_test_database():
    """Apply the real Alembic chain once, only against the dedicated test database."""
    config = Config("alembic.ini")
    command.upgrade(config, "head")
    yield
    engine.dispose()


@pytest.fixture(autouse=True)
def clean_database(migrated_test_database):
    with engine.begin() as connection:
        connection.execute(text("""
            TRUNCATE TABLE banking.audit_logs, banking.notifications, banking.otp_challenges,
            banking.transaction_entries, banking.transactions, banking.transfers, banking.beneficiaries,
            banking.auth_sessions, banking.registration_requests, banking.role_permissions,
            banking.user_roles, banking.permissions, banking.roles, banking.accounts, banking.users
            RESTART IDENTITY CASCADE
        """))
    db = SessionLocal()
    seed(db)
    try:
        yield
    finally:
        db.close()


@pytest.fixture
def db():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client(db):
    def override_db():
        yield db

    app.dependency_overrides[get_db] = override_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def fake_otp(monkeypatch):
    sent: dict[str, str] = {}

    def deliver(destination: str, code: str) -> None:
        sent[destination] = code

    monkeypatch.setattr("app.services.otp.deliver_otp", deliver)
    return sent


def auth_headers(client: TestClient, identifier: str, password: str) -> dict[str, str]:
    response = client.post("/auth/login", json={"identifier": identifier, "password": password})
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


@pytest.fixture
def admin_headers(client):
    return auth_headers(client, "admin@banking.local", "ChangeThisAdminPassword123!")


@pytest.fixture
def customers(db, client):
    role = db.query(Role).filter_by(code="CUSTOMER").one()
    password = "CustomerPass123!"
    alice = User(email="alice@example.com", phone="0900000001", full_name="Alice", password_hash=hash_password(password), status=UserStatus.active)
    bob = User(email="bob@example.com", phone="0900000002", full_name="Bob", password_hash=hash_password(password), status=UserStatus.active)
    settlement = User(email="settlement@example.com", full_name="Settlement", password_hash=hash_password(password), status=UserStatus.active)
    alice.roles.append(role); bob.roles.append(role)
    db.add_all([alice, bob, settlement]); db.flush()
    alice_account = Account(owner_id=alice.id, account_number="100000000001", currency="VND", status=AccountStatus.active)
    bob_account = Account(owner_id=bob.id, account_number="100000000002", currency="VND", status=AccountStatus.active)
    settlement_account = Account(owner_id=settlement.id, account_number="999000000001", currency="VND", status=AccountStatus.active)
    db.add_all([alice_account, bob_account, settlement_account]); db.flush()
    funding = Transaction(idempotency_key=uuid4(), reference="TEST-FUNDING", status=TransactionStatus.pending, description="Test funding")
    db.add(funding); db.flush()
    db.add_all([
        TransactionEntry(transaction_id=funding.id, account_id=alice_account.id, amount=Decimal("1000")),
        TransactionEntry(transaction_id=funding.id, account_id=settlement_account.id, amount=Decimal("-1000")),
    ])
    db.flush()
    funding.status = TransactionStatus.posted
    db.commit()
    return {
        "password": password, "alice": alice, "bob": bob,
        "alice_account": alice_account, "bob_account": bob_account,
        "alice_headers": auth_headers(client, alice.email, password),
        "bob_headers": auth_headers(client, bob.email, password),
    }
