from datetime import datetime, timezone
from decimal import Decimal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.models import Account, Beneficiary, Notification, Transaction, TransactionEntry, TransactionStatus, User
from app.db.session import get_db
from app.schemas.banking import AccountResponse, BeneficiaryInput, ProfileUpdate

router = APIRouter(tags=["customer"])


def account_balance(db: Session, account_id: UUID) -> Decimal:
    return db.query(func.coalesce(func.sum(TransactionEntry.amount), 0)).join(Transaction).filter(
        TransactionEntry.account_id == account_id, Transaction.status == TransactionStatus.posted
    ).scalar() or Decimal("0")


def own_account(db: Session, user: User, account_id: UUID) -> Account:
    account = db.get(Account, account_id)
    if account is None or account.owner_id != user.id:
        raise HTTPException(status_code=404, detail="Account not found")
    return account


def serialize_account(db: Session, account: Account) -> AccountResponse:
    return AccountResponse(id=account.id, account_number=account.account_number, currency=account.currency,
                           status=account.status.value, balance=account_balance(db, account.id), updated_at=account.created_at)


@router.get("/profile")
def get_profile(current_user: User = Depends(get_current_user)) -> dict:
    return {"id": current_user.id, "email": current_user.email, "phone": current_user.phone,
            "username": current_user.username, "full_name": current_user.full_name, "status": current_user.status.value}


@router.patch("/profile")
def update_profile(payload: ProfileUpdate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    if payload.full_name is not None:
        current_user.full_name = payload.full_name
    db.commit()
    return get_profile(current_user)


@router.get("/accounts", response_model=list[AccountResponse])
def list_accounts(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[AccountResponse]:
    return [serialize_account(db, account) for account in db.query(Account).filter(Account.owner_id == current_user.id).order_by(Account.created_at).all()]


@router.get("/accounts/{account_id}", response_model=AccountResponse)
def get_account(account_id: UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> AccountResponse:
    return serialize_account(db, own_account(db, current_user, account_id))


@router.get("/accounts/{account_id}/balance")
def get_balance(account_id: UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    account = own_account(db, current_user, account_id)
    return {"account_id": account.id, "balance": account_balance(db, account.id), "currency": account.currency, "as_of": datetime.now(timezone.utc)}


@router.get("/beneficiaries", response_model=None)
def list_beneficiaries(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[Beneficiary]:
    return db.query(Beneficiary).filter(Beneficiary.owner_id == current_user.id).order_by(Beneficiary.created_at.desc()).all()


@router.post("/beneficiaries", status_code=status.HTTP_201_CREATED, response_model=None)
def create_beneficiary(payload: BeneficiaryInput, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Beneficiary:
    exists = db.query(Beneficiary).filter(Beneficiary.owner_id == current_user.id, Beneficiary.account_number == payload.account_number, Beneficiary.bank_code == payload.bank_code).first()
    if exists:
        raise HTTPException(status_code=409, detail="Beneficiary already exists")
    internal = db.query(Account).filter(Account.account_number == payload.account_number).first() is not None
    item = Beneficiary(owner_id=current_user.id, **payload.model_dump(), is_internal=internal)
    db.add(item); db.commit(); db.refresh(item)
    return item


@router.patch("/beneficiaries/{beneficiary_id}", response_model=None)
def update_beneficiary(beneficiary_id: UUID, payload: BeneficiaryInput, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Beneficiary:
    item = db.get(Beneficiary, beneficiary_id)
    if item is None or item.owner_id != current_user.id:
        raise HTTPException(status_code=404, detail="Beneficiary not found")
    for key, value in payload.model_dump().items():
        setattr(item, key, value)
    item.is_internal = db.query(Account).filter(Account.account_number == item.account_number).first() is not None
    db.commit(); db.refresh(item)
    return item


@router.delete("/beneficiaries/{beneficiary_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_beneficiary(beneficiary_id: UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    item = db.get(Beneficiary, beneficiary_id)
    if item is None or item.owner_id != current_user.id:
        raise HTTPException(status_code=404, detail="Beneficiary not found")
    db.delete(item); db.commit()


@router.get("/notifications")
def list_notifications(unread_only: bool = False, limit: int = Query(default=50, le=100), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    query = db.query(Notification).filter(Notification.user_id == current_user.id)
    if unread_only:
        query = query.filter(Notification.read_at.is_(None))
    return {"unread_count": db.query(Notification).filter(Notification.user_id == current_user.id, Notification.read_at.is_(None)).count(), "items": query.order_by(Notification.created_at.desc()).limit(limit).all()}


@router.post("/notifications/{notification_id}/read", status_code=status.HTTP_204_NO_CONTENT)
def mark_notification_read(notification_id: UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    item = db.get(Notification, notification_id)
    if item is None or item.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Notification not found")
    item.read_at = datetime.now(timezone.utc); db.commit()


@router.get("/transactions")
def list_transactions(account_id: UUID | None = None, page: int = Query(default=1, ge=1), page_size: int = Query(default=20, ge=1, le=100), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    accounts = db.query(Account.id).filter(Account.owner_id == current_user.id)
    if account_id is not None:
        own_account(db, current_user, account_id); accounts = accounts.filter(Account.id == account_id)
    query = db.query(Transaction).join(TransactionEntry).filter(TransactionEntry.account_id.in_(accounts)).distinct()
    total = query.count()
    items = query.order_by(Transaction.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()
    return {"page": page, "page_size": page_size, "total": total, "items": items}


@router.get("/transactions/{transaction_id}", response_model=None)
def transaction_detail(transaction_id: UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Transaction:
    transaction = db.get(Transaction, transaction_id)
    if transaction is None or not any(entry.account_id in {a.id for a in current_user.accounts} for entry in transaction.entries):
        raise HTTPException(status_code=404, detail="Transaction not found")
    return transaction
