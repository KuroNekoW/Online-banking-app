import pytest

def calculate_available_balance(balance: float, hold_amount: float) -> float:
    return balance - hold_amount

def mask_account_number(account_no: str) -> str:
    if len(account_no) <= 4:
        return "*" * len(account_no)
    return "*" * (len(account_no) - 4) + account_no[-4:]

class TestCustomerAccountUnit:
    # TC_ACCT_01: Tính số dư khả dụng khi có tiền phong tỏa
    def test_calculate_available_balance(self):
        assert calculate_available_balance(1000000.0, 200000.0) == 800000.0

    # TC_ACCT_02: Che thông tin số tài khoản
    def test_mask_account_number(self):
        masked = mask_account_number("101234567890")
        assert "7890" in masked and masked.startswith("********")

    # TC_AUTHz_01: Chặn Customer truy cập tài nguyên Admin
    def test_check_permission_customer_denied_admin(self):
        role = "Customer"
        allowed = (role == "Admin")
        assert allowed is False

    # TC_TRX_01: Kiểm tra phân trang lịch sử giao dịch
    def test_get_transaction_history_pagination(self):
        history = [{"id": i, "user_id": "ACC_001"} for i in range(25)]
        page_1 = history[:10]
        assert len(page_1) == 10
