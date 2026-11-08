## Kết quả kiểm thử tự động API — Nhóm 5

**Nguồn bằng chứng:** `automation_basic.xml` do pytest xuất từ lần chạy thực tế.

**Tổng số:** 9; **Passed:** 9; **Failed:** 0; **Error:** 0; **Skipped:** 0; **Pass Rate:** 100.0%.

**Môi trường:** FastAPI + pytest + HTTPX/FastAPI TestClient + PostgreSQL (database `banking_test` riêng). OTP sử dụng fixture giả lập, không gửi email thật.

**Loại kiểm thử:** API Automation Testing / Backend Integration Testing; không phải UI Automation.

| Test Case | Script | Status |
|---|---|---|
| TC_AUTH_02 | `test_tc_auth_02_login_success` | PASSED |
| TC_AUTH_05 | `test_tc_auth_05_logout_revokes_session` | PASSED |
| TC_ACCT_01 | `test_tc_acct_01_list_accounts_balance` | PASSED |
| TC_ACCT_03 | `test_tc_acct_03_view_profile` | PASSED |
| TC_ACCT_05 | `test_tc_acct_05_cannot_view_other_account` | PASSED |
| TC_TRSF_02 | `test_tc_trsf_02_reject_insufficient_balance` | PASSED |
| TC_TRSF_03 | `test_tc_trsf_03_reject_zero` | PASSED |
| TC_TRSF_14 | `test_tc_trsf_14_reject_negative` | PASSED |
| TC_ADM_05 | `test_tc_adm_05_customer_forbidden_from_admin_roles` | PASSED |

**Đánh giá:** Các test FAILED/ERROR (nếu có) cần được phân tích, đối chiếu SRS và ghi vào Defect Summary. Tỷ lệ Passed không đồng nghĩa với Code Coverage. Không suy ra hệ thống không còn lỗi khi tất cả test đều Passed.
