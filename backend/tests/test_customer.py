from datetime import datetime, timezone
from decimal import Decimal
from uuid import uuid4

from app.db.models import (
    Notification,
    NotificationType,
    Transaction,
    TransactionEntry,
    TransactionStatus,
)


def _add_posted_transaction(
    db, customers, reference: str, created_at: datetime
) -> Transaction:
    transaction = Transaction(
        idempotency_key=uuid4(),
        reference=reference,
        status=TransactionStatus.posted,
        description=reference,
        created_at=created_at,
        posted_at=created_at,
    )
    db.add(transaction)
    db.flush()
    db.add_all([
        TransactionEntry(
            transaction_id=transaction.id,
            account_id=customers["alice_account"].id,
            amount=Decimal("10"),
        ),
        TransactionEntry(
            transaction_id=transaction.id,
            account_id=customers["bob_account"].id,
            amount=Decimal("-10"),
        ),
    ])
    return transaction


def test_customer_cannot_read_another_customers_account(client, customers):
    response = client.get(f"/accounts/{customers['bob_account'].id}", headers=customers["alice_headers"])
    assert response.status_code == 404


def test_beneficiary_is_scoped_to_owner(client, customers):
    created = client.post("/beneficiaries", headers=customers["alice_headers"], json={
        "nickname": "Bob", "account_number": customers["bob_account"].account_number,
        "account_name": "Bob", "bank_code": None,
    })
    assert created.status_code == 201
    assert client.get("/beneficiaries", headers=customers["bob_headers"]).json() == []


def test_notifications_return_serializable_items(client, customers, db):
    notification = Notification(
        user_id=customers["alice"].id,
        type=NotificationType.security,
        title="Security alert",
        body="A new sign-in was detected.",
    )
    db.add(notification)
    db.commit()

    response = client.get("/notifications", headers=customers["alice_headers"])

    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["unread_count"] == 1
    assert payload["items"][0]["id"] == str(notification.id)
    assert payload["items"][0]["type"] == "security"
    assert payload["items"][0]["title"] == "Security alert"


def test_transaction_date_filter_includes_both_vietnam_calendar_day_boundaries(
    client, customers, db
):
    before_start = _add_posted_transaction(
        db,
        customers,
        "BEFORE-DATE-RANGE",
        datetime(2026, 9, 19, 16, 59, 59, 999999, tzinfo=timezone.utc),
    )
    at_start = _add_posted_transaction(
        db,
        customers,
        "AT-DATE-RANGE-START",
        datetime(2026, 9, 19, 17, 0, tzinfo=timezone.utc),
    )
    at_end = _add_posted_transaction(
        db,
        customers,
        "AT-DATE-RANGE-END",
        datetime(2026, 9, 20, 16, 59, 59, 999999, tzinfo=timezone.utc),
    )
    after_end = _add_posted_transaction(
        db,
        customers,
        "AFTER-DATE-RANGE",
        datetime(2026, 9, 20, 17, 0, tzinfo=timezone.utc),
    )
    db.commit()

    response = client.get(
        "/transactions",
        headers=customers["alice_headers"],
        params={"start_date": "2026-09-20", "end_date": "2026-09-20"},
    )

    assert response.status_code == 200, response.text
    references = {item["reference"] for item in response.json()["items"]}
    assert at_start.reference in references
    assert at_end.reference in references
    assert before_start.reference not in references
    assert after_end.reference not in references


def test_transaction_date_filter_rejects_reversed_range(client, customers):
    response = client.get(
        "/transactions",
        headers=customers["alice_headers"],
        params={"start_date": "2026-09-21", "end_date": "2026-09-20"},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Start date must not be after end date"


def test_transaction_date_filter_rejects_invalid_calendar_date(client, customers):
    response = client.get(
        "/transactions",
        headers=customers["alice_headers"],
        params={"start_date": "2026-04-31"},
    )

    assert response.status_code == 422
