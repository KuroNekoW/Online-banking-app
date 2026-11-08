SE113 - Nhom 5 - BASIC AUTOMATION TESTING (9 KICH BAN)
===================================================
Chi dung cac API da co trong Backend - KHONG test tu dong khoa tai khoan,
KHONG test Admin lock, KHONG test logic chua hoan thien, KHONG sua DB demo.

1) Giai nen ZIP vao thu muc goc Online-banking-app, noi co docker-compose.yml
   Vidu:
   Online-banking-app/backend/tests/test_automation_basic.py
   Online-banking-app/automation/run_basic.ps1
   Online-banking-app/automation/generate_report.py

2) Mo Docker Desktop.

3) Mo PowerShell tai thu muc goc Online-banking-app va chay:
   powershell -ExecutionPolicy Bypass -File .\automation\run_basic.ps1

4) Luu minh chung trong backend/reports:
   automation_basic.xml   - Du lieu ket qua pytest goc
   automation_basic.html  - Bao cao de chup man hinh
   automation_basic.csv   - Danh sach status tung bai test
   automation_basic.md    - Tom tat ket qua cho Google Docs

9 KICH BAN (API subscenarios)
- TC_AUTH_02 : Dang nhap dung, nhan access token va truy van /auth/me
- TC_AUTH_05 : Dang xuat, token cu bi tu choi
- TC_ACCT_01 : Xem danh sach tai khoan va so du
- TC_ACCT_03 : Xem thong tin ca nhan
- TC_ACCT_05 : Khong duoc xem tai khoan khach hang khac
- TC_TRSF_02 : Tu choi so tien > so du (400)
- TC_TRSF_03 : Tu choi so tien bang 0 (422)
- TC_TRSF_14 : Tu choi so tien am (422)
- TC_ADM_05 : Customer khong duoc truy cap Admin API (403)

CHU Y:
- Cac kich ban nay kiem thu phan API cua TC Chuong 6, khong bao phu
  tat ca thao tac UI, ngu canh va ket qua mong doi cua TC thu cong.
- Moi bai dung PostgreSQL banking_test rieng. Fixture conftest.py se TRUNCATE
  database test truoc tung bai. Tuyet doi khong chuyen TEST_DATABASE_URL
  sang DB development.
- Danh sach 9 bai khong bao gom test khoa tai khoan, OTP, interbank.
- Chua chay test tren may nhom thi KHONG ghi Passed vao Google Docs.
- Pass rate != code coverage. Test API/integration khong phai Unit Test thuan tuy.
