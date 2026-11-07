from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload

from app.api.deps import get_current_admin
from app.db.models import AuditLog, AuthSession, Role, User, UserStatus
from app.db.session import get_db
from app.schemas.banking import RoleAssignment

router = APIRouter(prefix="/admin", tags=["admin"])


def audit(db: Session, actor: User, action: str, target_type: str, target_id: UUID, **metadata) -> None:
    db.add(AuditLog(actor_user_id=actor.id, action=action, target_type=target_type, target_id=target_id, metadata_=metadata))


def customer_view(user: User) -> dict:
    return {"id": user.id, "email": user.email, "phone": user.phone, "full_name": user.full_name,
            "status": user.status.value, "roles": [role.code for role in user.roles], "created_at": user.created_at}


@router.get("/customers")
def list_customers(q: str | None = None, account_status: UserStatus | None = None, page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100), current_admin: User = Depends(get_current_admin), db: Session = Depends(get_db)) -> dict:
    query = db.query(User).options(joinedload(User.roles)).join(User.roles).filter(Role.code == "CUSTOMER")
    if q:
        query = query.filter(or_(User.email.ilike(f"%{q}%"), User.phone.ilike(f"%{q}%"), User.full_name.ilike(f"%{q}%")))
    if account_status:
        query = query.filter(User.status == account_status)
    total = query.count(); items = query.order_by(User.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()
    audit(db, current_admin, "customer.list", "customer", current_admin.id); db.commit()
    return {"page": page, "page_size": page_size, "total": total, "items": [customer_view(user) for user in items]}


@router.get("/customers/{user_id}")
def customer_detail(user_id: UUID, current_admin: User = Depends(get_current_admin), db: Session = Depends(get_db)) -> dict:
    user = db.query(User).options(joinedload(User.roles), joinedload(User.accounts)).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="Customer not found")
    audit(db, current_admin, "customer.view", "customer", user.id); db.commit()
    return customer_view(user) | {"accounts": [{"id": a.id, "account_number": a.account_number, "status": a.status.value, "currency": a.currency} for a in user.accounts]}


@router.post("/customers/{user_id}/lock", status_code=status.HTTP_204_NO_CONTENT)
def lock_customer(user_id: UUID, reason: str = Query(min_length=3, max_length=255), current_admin: User = Depends(get_current_admin), db: Session = Depends(get_db)) -> None:
    user = db.get(User, user_id)
    if user is None or "CUSTOMER" not in {r.code for r in user.roles}:
        raise HTTPException(status_code=404, detail="Customer not found")
    user.status = UserStatus.locked
    db.query(AuthSession).filter(AuthSession.user_id == user.id, AuthSession.revoked_at.is_(None)).update({AuthSession.revoked_at: datetime.now(timezone.utc), AuthSession.revoke_reason: "admin_lock"})
    audit(db, current_admin, "customer.lock", "customer", user.id, reason=reason); db.commit()


@router.post("/customers/{user_id}/unlock", status_code=status.HTTP_204_NO_CONTENT)
def unlock_customer(user_id: UUID, reason: str = Query(min_length=3, max_length=255), current_admin: User = Depends(get_current_admin), db: Session = Depends(get_db)) -> None:
    user = db.get(User, user_id)
    if user is None or "CUSTOMER" not in {r.code for r in user.roles}:
        raise HTTPException(status_code=404, detail="Customer not found")
    user.status, user.failed_login_count = UserStatus.active, 0
    audit(db, current_admin, "customer.unlock", "customer", user.id, reason=reason); db.commit()


@router.get("/roles")
def list_roles(current_admin: User = Depends(get_current_admin), db: Session = Depends(get_db)) -> list[dict]:
    roles = db.query(Role).options(joinedload(Role.permissions)).all()
    return [{"id": role.id, "code": role.code, "name": role.name, "permissions": [p.code for p in role.permissions]} for role in roles]


@router.put("/users/{user_id}/role")
def assign_role(user_id: UUID, payload: RoleAssignment, current_admin: User = Depends(get_current_admin), db: Session = Depends(get_db)) -> dict:
    if user_id == current_admin.id:
        raise HTTPException(status_code=400, detail="Administrators cannot modify their own role")
    user = db.query(User).options(joinedload(User.roles)).filter(User.id == user_id).first()
    role = db.query(Role).filter(Role.code == payload.role_code).first()
    if user is None or role is None:
        raise HTTPException(status_code=404, detail="User or role not found")
    before = [r.code for r in user.roles]
    user.roles = [role]
    db.query(AuthSession).filter(AuthSession.user_id == user.id, AuthSession.revoked_at.is_(None)).update({AuthSession.revoked_at: datetime.now(timezone.utc), AuthSession.revoke_reason: "role_changed"})
    audit(db, current_admin, "role.assign", "user", user.id, before=before, after=[role.code]); db.commit()
    return customer_view(user)


@router.get("/audit-logs", response_model=None)
def list_audit_logs(limit: int = Query(100, ge=1, le=500), current_admin: User = Depends(get_current_admin), db: Session = Depends(get_db)) -> list[AuditLog]:
    return db.query(AuditLog).order_by(AuditLog.created_at.desc()).limit(limit).all()
