from decimal import Decimal
from uuid import uuid4

from sqlalchemy import func

from app.db.models import Transaction, TransactionEntry, Transfer, TransferStatus


def test_internal_transfer_is_idempotent_balanced_and_updates_balances(client, customers, db, fake_otp):
    payload = {
        "source_account_id": str(customers["alice_account"].id),
        "destination_account_number": customers["bob_account"].account_number,
        "amount": "250", "description": "Lunch", "idempotency_key": str(uuid4()),
    }
    created = client.post("/transfers", headers=customers["alice_headers"], json=payload)
    assert created.status_code == 201, created.text
    duplicate = client.post("/transfers", headers=customers["alice_headers"], json=payload)
    assert duplicate.status_code == 201
    assert duplicate.json()["id"] == created.json()["id"]
    transfer_id = created.json()["id"]
    confirmed = client.post(f"/transfers/{transfer_id}/confirm", headers=customers["alice_headers"])
    assert confirmed.status_code == 200, confirmed.text
    completed = client.post(f"/transfers/{transfer_id}/authenticate", headers=customers["alice_headers"], json={"code": fake_otp["alice@example.com"]})
    assert completed.status_code == 200, completed.text
    assert completed.json()["status"] == "completed"
    alice = client.get(f"/accounts/{customers['alice_account'].id}/balance", headers=customers["alice_headers"]).json()
    bob = client.get(f"/accounts/{customers['bob_account'].id}/balance", headers=customers["bob_headers"]).json()
    assert Decimal(alice["balance"]) == Decimal("750")
    assert Decimal(bob["balance"]) == Decimal("250")
    transfer = db.get(Transfer, transfer_id)
    assert db.query(Transfer).filter_by(id=transfer.id, status=TransferStatus.completed).count() == 1
    ledger_sum = db.query(func.sum(TransactionEntry.amount)).join(Transaction).filter(Transaction.transfer_id == transfer.id).scalar()
    assert ledger_sum == Decimal("0")


def test_transfer_rejects_insufficient_balance(client, customers):
    response = client.post("/transfers", headers=customers["alice_headers"], json={
        "source_account_id": str(customers["alice_account"].id),
        "destination_account_number": customers["bob_account"].account_number,
        "amount": "1001", "idempotency_key": str(uuid4()),
    })
    assert response.status_code == 400
