from app.db.models import Role, User


def test_registration_verification_creates_customer_and_account(client, db, fake_otp):
    response = client.post("/auth/register", json={
        "email": "new.customer@example.com", "phone": "0912345678",
        "full_name": "New Customer", "password": "StrongPass123!",
    })
    assert response.status_code == 201
    challenge_id = response.json()["challenge_id"]
    verify = client.post("/auth/register/verify", json={"challenge_id": challenge_id, "code": fake_otp["new.customer@example.com"]})
    assert verify.status_code == 201, verify.text
    user = db.query(User).filter_by(email="new.customer@example.com").one()
    assert {role.code for role in user.roles} == {"CUSTOMER"}
    assert len(user.accounts) == 1


def test_non_admin_cannot_access_admin_endpoints(client, customers):
    response = client.get("/admin/customers", headers=customers["alice_headers"])
    assert response.status_code == 403


def test_admin_lock_revokes_existing_customer_session(client, customers, admin_headers):
    response = client.post(f"/admin/customers/{customers['alice'].id}/lock?reason=Test+lock", headers=admin_headers)
    assert response.status_code == 204
    assert client.get("/profile", headers=customers["alice_headers"]).status_code == 401
