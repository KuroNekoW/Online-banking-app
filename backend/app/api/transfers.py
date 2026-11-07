import uuid
from datetime import datetime, timezone
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.customer import account_balance, own_account
from app.api.deps import get_current_user
from app.db.models import Account, AccountStatus, Notification, NotificationType, OtpChallenge, OtpPurpose, OtpStatus, Transaction, TransactionEntry, TransactionStatus, Transfer, TransferStatus, TransferType, User
from app.db.session import get_db
from app.schemas.banking import OtpCode, TransferCreate, TransferResponse
from app.services.otp import create_otp, verify_otp

router = APIRouter(prefix="/transfers", tags=["transfers"])


def serialize(transfer: Transfer) -> TransferResponse:
    return TransferResponse(id=transfer.id, reference=transfer.reference, type=transfer.type.value, status=transfer.status.value,
                            source_account_id=transfer.source_account_id, destination_account_id=transfer.destination_account_id,
                            amount=transfer.amount, fee=transfer.fee, currency=transfer.currency, description=transfer.description,
                            created_at=transfer.created_at, completed_at=transfer.completed_at)


def get_own_transfer(db: Session, user: User, transfer_id: uuid.UUID) -> Transfer:
    transfer = db.get(Transfer, transfer_id)
    if transfer is None or transfer.customer_id != user.id:
        raise HTTPException(status_code=404, detail="Transfer not found")
    return transfer


def validate_source(db: Session, user: User, source_id: uuid.UUID, amount: Decimal) -> Account:
    source = own_account(db, user, source_id)
    if source.status != AccountStatus.active:
        raise HTTPException(status_code=400, detail="Source account is not active")
    if account_balance(db, source.id) < amount:
        raise HTTPException(status_code=400, detail="Insufficient available balance")
    return source


@router.post("", response_model=TransferResponse, status_code=status.HTTP_201_CREATED)
def create_transfer(payload: TransferCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> TransferResponse:
    existing = db.query(Transfer).filter(Transfer.customer_id == current_user.id, Transfer.idempotency_key == payload.idempotency_key).first()
    if existing:
        return serialize(existing)
    source = validate_source(db, current_user, payload.source_account_id, payload.amount)
    destination = db.query(Account).filter(Account.account_number == payload.destination_account_number).first()
    is_internal = destination is not None and not payload.destination_bank_code
    if is_internal and destination.id == source.id:
        raise HTTPException(status_code=400, detail="Source and destination cannot be the same")
    if is_internal and destination.status != AccountStatus.active:
        raise HTTPException(status_code=400, detail="Destination account is not active")
    transfer = Transfer(customer_id=current_user.id, source_account_id=source.id,
                        destination_account_id=destination.id if is_internal else None,
                        type=TransferType.internal if is_internal else TransferType.interbank,
                        reference=f"TRF-{uuid.uuid4().hex[:16].upper()}", idempotency_key=payload.idempotency_key,
                        amount=payload.amount, fee=Decimal("0"), currency=source.currency, description=payload.description)
    db.add(transfer); db.commit(); db.refresh(transfer)
    return serialize(transfer)


@router.post("/{transfer_id}/confirm")
def confirm_transfer(transfer_id: uuid.UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    transfer = get_own_transfer(db, current_user, transfer_id)
    if transfer.status == TransferStatus.completed:
        return {"transfer": serialize(transfer), "message": "Transfer has already completed"}
    if transfer.status != TransferStatus.draft:
        raise HTTPException(status_code=409, detail="Transfer cannot be confirmed in its current state")
    validate_source(db, current_user, transfer.source_account_id, transfer.amount + transfer.fee)
    transfer.status = TransferStatus.pending_authentication
    challenge = create_otp(db, OtpPurpose.transfer_authentication, current_user.email, user_id=current_user.id, transfer_id=transfer.id)
    db.commit()
    return {"transfer": serialize(transfer), "challenge_id": challenge.id, "expires_at": challenge.expires_at}


@router.post("/{transfer_id}/authenticate", response_model=TransferResponse)
def authenticate_transfer(transfer_id: uuid.UUID, payload: OtpCode, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> TransferResponse:
    transfer = get_own_transfer(db, current_user, transfer_id)
    if transfer.status == TransferStatus.completed:
        return serialize(transfer)
    if transfer.status != TransferStatus.pending_authentication:
        raise HTTPException(status_code=409, detail="Transfer is not awaiting authentication")
    challenge = db.query(OtpChallenge).filter_by(transfer_id=transfer.id).order_by(OtpChallenge.created_at.desc()).first()
    if challenge is None:
        raise HTTPException(status_code=400, detail="OTP challenge not found")
    verified = verify_otp(db, challenge.id, payload.code, OtpPurpose.transfer_authentication)
    validate_source(db, current_user, transfer.source_account_id, transfer.amount + transfer.fee)
    transfer.authenticated_at = datetime.now(timezone.utc)
    transfer.status = TransferStatus.processing
    if transfer.type == TransferType.internal:
        # Entries must be created while pending. The database makes posted entries immutable.
        ledger = Transaction(idempotency_key=uuid.uuid4(), reference=f"LED-{transfer.reference}", transfer_id=transfer.id, status=TransactionStatus.pending,
                             description=transfer.description)
        db.add(ledger); db.flush()
        db.add_all([TransactionEntry(transaction_id=ledger.id, account_id=transfer.source_account_id, amount=-transfer.amount),
                    TransactionEntry(transaction_id=ledger.id, account_id=transfer.destination_account_id, amount=transfer.amount)])
        db.flush()
        ledger.status, ledger.posted_at = TransactionStatus.posted, datetime.now(timezone.utc)
        transfer.status, transfer.completed_at = TransferStatus.completed, datetime.now(timezone.utc)
        receiver = db.get(Account, transfer.destination_account_id)
        db.add(Notification(user_id=current_user.id, transfer_id=transfer.id, type=NotificationType.transfer, title="Transfer completed", body=f"Transfer {transfer.reference} completed"))
        db.add(Notification(user_id=receiver.owner_id, transfer_id=transfer.id, type=NotificationType.transfer, title="Incoming transfer", body=f"Received {transfer.amount} {transfer.currency}"))
    else:
        # External banking is intentionally simulated: leave a traceable pending result for polling/reconciliation.
        transfer.status, transfer.external_reference = TransferStatus.pending_external, f"SIM-{uuid.uuid4().hex[:12].upper()}"
        db.add(Notification(user_id=current_user.id, transfer_id=transfer.id, type=NotificationType.transfer, title="Transfer processing", body=f"Interbank transfer {transfer.reference} is processing"))
    verified.status, verified.consumed_at = OtpStatus.consumed, datetime.now(timezone.utc)
    db.commit(); db.refresh(transfer)
    return serialize(transfer)


@router.get("/{transfer_id}", response_model=TransferResponse)
def transfer_detail(transfer_id: uuid.UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> TransferResponse:
    return serialize(get_own_transfer(db, current_user, transfer_id))


@router.get("/by-reference/{reference}", response_model=TransferResponse)
def transfer_by_reference(reference: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> TransferResponse:
    transfer = db.query(Transfer).filter(Transfer.reference == reference, Transfer.customer_id == current_user.id).first()
    if transfer is None:
        raise HTTPException(status_code=404, detail="Transfer not found")
    return serialize(transfer)
