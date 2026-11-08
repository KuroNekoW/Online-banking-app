"""SE113 Group 5 - basic API automation scenarios, no account-locking tests.

These tests require the existing backend/tests/conftest.py fixtures and the
DEDICATED banking_test database. They are API integration tests, not UI tests.
"""
from decimal import Decimal
from uuid import uuid4


def _transfer_request(customers, amount):
    return {
        "source_account_id": str(customers["alice_account"].id),
        "destination_account_number": customers["bob_account"].account_number,
        "amount": str(amount),
        "description": "SE113 basic automation test",
        "idempotency_key": str(uuid4()),
    }


def test_tc_auth_02_login_success(client, customers):
    """TC_AUTH_02 (API scope): valid credentials yield token and identity."""
    resp = client.post("/auth/login", json={
        "identifier": customers["alice"].email,
        "password": customers["password"],
    })
    assert resp.status_code == 200, resp.text
    access_token = resp.json().get("access_token")
    assert access_token, "Login must return an access token"
    me = client.get("/auth/me", headers={"Authorization": f"Bearer {access_token}"})
    assert me.status_code == 200, me.text
    assert me.json()["email"] == customers["alice"].email


def test_tc_auth_05_logout_revokes_session(client, customers):
    """TC_AUTH_05 (API scope): logout revokes the current session."""
    headers = customers["alice_headers"]
    logout = client.post("/auth/logout", headers=headers)
    assert logout.status_code == 204, logout.text
    profile = client.get("/profile", headers=headers)
    assert profile.status_code == 401, profile.text


def test_tc_acct_01_list_accounts_balance(client, customers):
    """TC_ACCT_01 (API scope): owner sees her account and seeded balance."""
    resp = client.get("/accounts", headers=customers["alice_headers"])
    assert resp.status_code == 200, resp.text
    items = resp.json()
    assert len(items) == 1, items
    assert items[0]["account_number"] == customers["alice_account"].account_number
    assert Decimal(str(items[0]["balance"])) == Decimal("1000")


def test_tc_acct_03_view_profile(client, customers):
    """TC_ACCT_03 (API scope): signed-in customer sees own profile."""
    resp = client.get("/profile", headers=customers["alice_headers"])
    assert resp.status_code == 200, resp.text
    assert resp.json()["email"] == customers["alice"].email
    assert resp.json()["full_name"] == customers["alice"].full_name


def test_tc_acct_05_cannot_view_other_account(client, customers):
    """TC_ACCT_05 (API scope): another user's account is inaccessible."""
    resp = client.get(
        f"/accounts/{customers['bob_account'].id}",
        headers=customers["alice_headers"],
    )
    assert resp.status_code == 404, resp.text


def test_tc_trsf_02_reject_insufficient_balance(client, customers):
    """TC_TRSF_02 (API scope): amount above available balance is refused."""
    resp = client.post(
        "/transfers",
        headers=customers["alice_headers"],
        json=_transfer_request(customers, "1001"),
    )
    assert resp.status_code == 400, resp.text


def test_tc_trsf_03_reject_zero(client, customers):
    """TC_TRSF_03 (API scope): amount=0 is invalid (HTTP 422)."""
    resp = client.post(
        "/transfers",
        headers=customers["alice_headers"],
        json=_transfer_request(customers, "0"),
    )
    assert resp.status_code == 422, resp.text


def test_tc_trsf_14_reject_negative(client, customers):
    """TC_TRSF_14 (API scope): amount below zero is invalid (HTTP 422)."""
    resp = client.post(
        "/transfers",
        headers=customers["alice_headers"],
        json=_transfer_request(customers, "-1"),
    )
    assert resp.status_code == 422, resp.text


def test_tc_adm_05_customer_forbidden_from_admin_roles(client, customers):
    """TC_ADM_05 (API scope): CUSTOMER cannot access Admin role listing."""
    resp = client.get("/admin/roles", headers=customers["alice_headers"])
    assert resp.status_code == 403, resp.text
