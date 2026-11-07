"""Create idempotent baseline roles, permissions, and the local Admin account."""
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import hash_password
from app.db.models import Permission, Role, User, UserStatus
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
    db.commit()


def main() -> None:
    with SessionLocal() as db:
        seed(db)


if __name__ == "__main__":
    main()
