"""Create baseline roles/Admin and optionally the local demo customers and balances."""
from decimal import Decimal
from uuid import UUID, uuid4

from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import hash_password
from app.db.models import Account, AccountStatus, Permission, Role, Transaction, TransactionEntry, TransactionStatus, User, UserStatus
from app.db.session import SessionLocal

ROLE_DEFINITIONS = {
    "CUSTOMER": "Mobile banking customer",
    "ADMIN": "System administrator",
}

PERMISSION_DEFINITIONS = {
    "account.read_own": "View own accounts and balances",
    "transfer.create": "Create transfer requests",
    "beneficiary.manage": "Manage own beneficiaries",
    "customer.read": "View customer records",
    "customer.lock": "Lock and unlock customer accounts",
    "role.manage": "Assign administrator roles",
}

ROLE_PERMISSIONS = {
    "CUSTOMER": {"account.read_own", "transfer.create", "beneficiary.manage"},
    "ADMIN": {"customer.read", "customer.lock", "role.manage"},
}

# Stable identifiers make the demo seed safe to run every time the API container starts.
DEMO_CUSTOMERS = (
    {
        "email": "alice.demo@banking.local",
        "phone": "0900000001",
        "full_name": "Demo Alice",
        "account_number": "100000000001",
        "opening_balance": Decimal("1000000.00"),
        "funding_reference": "DEMO-OPENING-ALICE",
        "idempotency_key": UUID("00000000-0000-4000-8000-000000000101"),
    },
    {
        "email": "bob.demo@banking.local",
        "phone": "0900000002",
        "full_name": "Demo Bob",
        "account_number": "100000000002",
        "opening_balance": Decimal("500000.00"),
        "funding_reference": "DEMO-OPENING-BOB",
        "idempotency_key": UUID("00000000-0000-4000-8000-000000000102"),
    },
)
DEMO_SYSTEM_EMAIL = "demo-ledger@banking.local"
DEMO_SYSTEM_ACCOUNT_NUMBER = "999000000001"


def seed(db: Session) -> None:
    roles: dict[str, Role] = {}
    for code, name in ROLE_DEFINITIONS.items():
        role = db.query(Role).filter(Role.code == code).first()
        if role is None:
            role = Role(code=code, name=name, is_system=True)
            db.add(role)
        roles[code] = role
    db.flush()

    permissions: dict[str, Permission] = {}
    for code, description in PERMISSION_DEFINITIONS.items():
        permission = db.query(Permission).filter(Permission.code == code).first()
        if permission is None:
            permission = Permission(code=code, description=description)
            db.add(permission)
        permissions[code] = permission
    db.flush()

    for role_code, permission_codes in ROLE_PERMISSIONS.items():
        role = roles[role_code]
        existing_codes = {permission.code for permission in role.permissions}
        for permission_code in permission_codes - existing_codes:
            role.permissions.append(permissions[permission_code])

    settings = get_settings()
    admin = db.query(User).filter(User.email == settings.seed_admin_email).first()
    if admin is None:
        admin = User(
            email=settings.seed_admin_email,
            full_name="Local Administrator",
            password_hash=hash_password(settings.seed_admin_password),
            status=UserStatus.active,
        )
        admin.roles.append(roles["ADMIN"])
        db.add(admin)
    elif roles["ADMIN"] not in admin.roles:
        admin.roles.append(roles["ADMIN"])
    if settings.seed_demo_data:
        seed_demo_customers(db, roles["CUSTOMER"], settings.seed_demo_password)
    db.commit()


def seed_demo_customers(db: Session, customer_role: Role, demo_password: str) -> None:
    """Create two funded demo customers using balanced, immutable opening ledger entries."""
    system_user = db.query(User).filter(User.email == DEMO_SYSTEM_EMAIL).first()
    if system_user is None:
        system_user = User(
            email=DEMO_SYSTEM_EMAIL,
            full_name="Demo Ledger Counterparty",
            password_hash=hash_password(uuid4().hex),
            status=UserStatus.active,
        )
        db.add(system_user)
        db.flush()

    system_account = db.query(Account).filter(Account.account_number == DEMO_SYSTEM_ACCOUNT_NUMBER).first()
    if system_account is None:
        system_account = Account(
            owner_id=system_user.id,
            account_number=DEMO_SYSTEM_ACCOUNT_NUMBER,
            currency="VND",
            status=AccountStatus.active,
        )
        db.add(system_account)
        db.flush()
    elif system_account.owner_id != system_user.id:
        raise RuntimeError(f"Demo ledger account number {DEMO_SYSTEM_ACCOUNT_NUMBER} is already in use")

    for definition in DEMO_CUSTOMERS:
        user = db.query(User).filter(User.email == definition["email"]).first()
        if user is None:
            user = User(
                email=definition["email"],
                phone=definition["phone"],
                full_name=definition["full_name"],
                password_hash=hash_password(demo_password),
                status=UserStatus.active,
            )
            user.roles.append(customer_role)
            db.add(user)
            db.flush()
        elif customer_role not in user.roles:
            user.roles.append(customer_role)

        account = db.query(Account).filter(Account.account_number == definition["account_number"]).first()
        if account is None:
            account = Account(
                owner_id=user.id,
                account_number=definition["account_number"],
                currency="VND",
                status=AccountStatus.active,
            )
            db.add(account)
            db.flush()
        elif account.owner_id != user.id:
            raise RuntimeError(f"Demo account number {definition['account_number']} is already in use")

        opening = db.query(Transaction).filter(Transaction.reference == definition["funding_reference"]).first()
        if opening is None:
            opening = Transaction(
                idempotency_key=definition["idempotency_key"],
                reference=definition["funding_reference"],
                status=TransactionStatus.pending,
                description="Local demo opening balance",
            )
            db.add(opening)
            db.flush()
            db.add_all(
                [
                    TransactionEntry(
                        transaction_id=opening.id,
                        account_id=account.id,
                        amount=definition["opening_balance"],
                    ),
                    TransactionEntry(
                        transaction_id=opening.id,
                        account_id=system_account.id,
                        amount=-definition["opening_balance"],
                    ),
                ]
            )
            db.flush()
            opening.status = TransactionStatus.posted


def main() -> None:
    with SessionLocal() as db:
        seed(db)
    settings = get_settings()
    if settings.seed_demo_data:
        print("Demo accounts are enabled:")
        for definition in DEMO_CUSTOMERS:
            print(
                f"  {definition['email']} / {settings.seed_demo_password} | "
                f"account {definition['account_number']} | "
                f"opening balance {definition['opening_balance']} VND"
            )


if __name__ == "__main__":
    main()
