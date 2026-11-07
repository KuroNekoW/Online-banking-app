from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field


class ProfileUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=150)


class BeneficiaryInput(BaseModel):
    nickname: str = Field(min_length=1, max_length=100)
    account_number: str = Field(min_length=4, max_length=34)
    account_name: str = Field(min_length=2, max_length=150)
    bank_code: str | None = Field(default=None, max_length=32)


class TransferCreate(BaseModel):
    source_account_id: UUID
    destination_account_number: str = Field(min_length=4, max_length=34)
    destination_bank_code: str | None = Field(default=None, max_length=32)
    amount: Decimal = Field(gt=0, max_digits=19, decimal_places=4)
    description: str | None = Field(default=None, max_length=255)
    idempotency_key: UUID


class OtpCode(BaseModel):
    code: str = Field(pattern=r"^\d{6}$")


class RoleAssignment(BaseModel):
    role_code: str = Field(min_length=3, max_length=50)


class AccountResponse(BaseModel):
    id: UUID
    account_number: str
    currency: str
    status: str
    balance: Decimal
    updated_at: datetime | None = None


class TransferResponse(BaseModel):
    id: UUID
    reference: str
    type: str
    status: str
    source_account_id: UUID
    destination_account_id: UUID | None
    amount: Decimal
    fee: Decimal
    currency: str
    description: str | None
    created_at: datetime
    completed_at: datetime | None
