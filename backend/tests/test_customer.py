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
