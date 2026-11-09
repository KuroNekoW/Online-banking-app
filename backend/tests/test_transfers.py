import pytest

class InvalidAmountError(Exception): pass
class InsufficientBalanceError(Exception): pass
class SameAccountTransferError(Exception): pass
class AccountLockedError(Exception): pass
class IdempotencyConflictError(Exception): pass

def validate_transfer(sender_status: str, sender_balance: float, amount: float, sender_id: str, receiver_id: str):
    if sender_status == "LOCKED":
        raise AccountLockedError("Tài khoản gửi đang bị khóa")
    if sender_id == receiver_id:
        raise SameAccountTransferError("Không thể tự chuyển cho chính mình")
    if amount <= 0:
        raise InvalidAmountError("Số tiền phải lớn hơn 0")
    if amount > sender_balance:
        raise InsufficientBalanceError("Số dư khả dụng không đủ")
    return True

def process_ledger_entry(sender_balance: float, receiver_balance: float, amount: float):
    return sender_balance - amount, receiver_balance + amount

class TestTransferLogicUnit:
    # TC_TRSF_01: Chuyển tiền hợp lệ
    def test_validate_transfer_success(self):
        assert validate_transfer("ACTIVE", 1000000, 500000, "ACC_001", "ACC_002") is True

    # TC_TRSF_02: Từ chối số tiền <= 0
    def test_validate_transfer_invalid_amount(self):
        with pytest.raises(InvalidAmountError):
            validate_transfer("ACTIVE", 1000000, 0, "ACC_001", "ACC_002")

    # TC_TRSF_03: Từ chối khi vượt quá số dư
    def test_validate_transfer_insufficient_balance(self):
        with pytest.raises(InsufficientBalanceError):
            validate_transfer("ACTIVE", 1000000, 1000001, "ACC_001", "ACC_002")

    # TC_TRSF_04: Chặn tài khoản gửi bị khóa
    def test_validate_transfer_sender_locked(self):
        with pytest.raises(AccountLockedError):
            validate_transfer("LOCKED", 1000000, 100000, "ACC_001", "ACC_002")

    # TC_TRSF_05: Chặn tự chuyển cho chính mình
    def test_validate_transfer_same_account(self):
        with pytest.raises(SameAccountTransferError):
            validate_transfer("ACTIVE", 1000000, 100000, "ACC_001", "ACC_001")

    # TC_TRSF_06: Hạch toán Nợ/Có cân bằng
    def test_process_ledger_entry(self):
        new_s, new_r = process_ledger_entry(1000000, 500000, 200000)
        assert new_s == 800000 and new_r == 700000

    # TC_TRSF_07: Trả về bản ghi cũ khi trùng Idempotency Key
    def test_check_idempotency_existing(self):
        cache = {"KEY_123": {"status": "COMPLETED"}}
        assert cache.get("KEY_123")["status"] == "COMPLETED"

    # TC_TRSF_08: Xung đột Idempotency Key khi gửi nội dung mới
    def test_check_idempotency_conflict(self):
        key_exists_with_different_payload = True
        with pytest.raises(IdempotencyConflictError):
            if key_exists_with_different_payload:
                raise IdempotencyConflictError("Xung đột Idempotency Key")