# Trạng thái dự án Online Banking

Cập nhật: 08/11/2026

> Tài liệu này là bản bàn giao nhanh để tiếp tục công việc khi không còn lịch sử hội thoại. Nguồn kiểm tra gồm mã nguồn hiện tại, `README.md`, `app/FE_README.md`, cấu hình Docker Compose và các file seed. Đây là dự án học tập/demo chạy local, không kết nối ngân hàng thật và không xử lý tiền thật.

## Tổng quan

- Frontend: Flutter, cấu trúc theo `core`, `models`, `providers`, `screens`, `services`, `widgets`.
- Backend: FastAPI, SQLAlchemy, Pydantic, PostgreSQL; schema được quản lý bằng Alembic.
- Môi trường local: Docker Compose chạy API, PostgreSQL và Mailpit; có PostgreSQL riêng cho test.
- Tài liệu yêu cầu gốc: [`docs.docx`](docs.docx). ERD: [`database-erd.puml`](database-erd.puml).
- Swagger/OpenAPI khi API chạy: `http://127.0.0.1:8000/docs`; health check: `http://127.0.0.1:8000/health`.

## Đã có

### Backend và dữ liệu

- Đăng ký có OTP, gửi lại OTP, đăng nhập, refresh/logout, quên mật khẩu và đổi mật khẩu.
- API hồ sơ, tài khoản/số dư, người thụ hưởng, thông báo, lịch sử giao dịch và chi tiết giao dịch.
- Chuyển khoản nội bộ với các bước tạo yêu cầu, xác nhận OTP/xác thực và tra cứu.
- API quản trị: danh sách/chi tiết khách hàng, khóa/mở khóa, vai trò và audit log.
- Phân quyền CUSTOMER/ADMIN; kiểm tra quyền và quyền sở hữu dữ liệu ở backend.
- Sổ cái dùng `transaction_entries`; số dư được tính từ bút toán. Seed demo tạo hai khách hàng có tài khoản và số dư ban đầu theo cách idempotent.
- Seed admin được cấu hình qua `SEED_ADMIN_EMAIL` và `SEED_ADMIN_PASSWORD` trong `.env`/Compose.
- OTP local được gửi vào Mailpit: giao diện hộp thư `http://127.0.0.1:8025`; không gửi đến email thật trong cấu hình này.
- Có test backend trong `backend/tests/` cho auth, customer và transfers; Compose cấu hình database test riêng.

### Frontend

- Có các màn hình đăng nhập, đăng ký/xác minh OTP, quên mật khẩu, trang chủ, chuyển khoản, lịch sử/chi tiết giao dịch, thông báo, người thụ hưởng, hồ sơ và đổi mật khẩu.
- Có các service gọi API và Provider quản lý trạng thái đăng nhập/ngân hàng.
- Base URL mặc định: Web/Windows `http://127.0.0.1:8000`; Android emulator `http://10.0.2.2:8000`.
- Access/refresh token hiện lưu bằng `flutter_secure_storage`; khi khởi tạo, token cũ trong SharedPreferences được chuyển sang kho bảo mật. API client có thử refresh một lần khi nhận 401.
- Đổi mật khẩu sẽ kết thúc phiên hiện tại và đưa người dùng về đăng nhập.
- Flutter hiện có smoke test khởi tạo ứng dụng; chưa có bộ test nghiệp vụ frontend/tích hợp đủ rộng.

## Các thay đổi gần nhất cần biết

- Sửa API lịch sử/chi tiết để tải và trả về các bút toán của giao dịch. Giao diện dùng bút toán để xác định tiền vào/ra và số tiền theo tài khoản.
- Tab lịch sử tải lại danh sách khi được mở; sau khi đóng trang chi tiết cũng tải lại.
- Bổ sung cấu hình URL mặc định theo nền tảng, xử lý token bảo mật/refresh và luồng đăng xuất sau đổi mật khẩu như mô tả ở trên.
- Android manifest được cấu hình quyền mạng và HTTP cho demo local. Không dùng cấu hình HTTP này như cấu hình production; triển khai thật cần HTTPS.
- Các thay đổi gần nhất chưa được xác nhận bằng chạy ứng dụng và luồng chuyển khoản thực tế trong phiên cập nhật này. `dart analyze lib` đã được thử nhưng không trả kết quả hoàn tất; chưa chạy lại test backend/Flutter.

## Còn thiếu / giới hạn đã biết

- Backend đã có API quản trị nhưng frontend chưa có màn hình quản trị khách hàng/khóa tài khoản/phân quyền.
- Chuyển khoản liên ngân hàng chưa triển khai thật; giữ ngoài phạm vi hiện tại theo yêu cầu. Không xem chức năng này là kết nối hoặc thanh toán liên ngân hàng thực tế.
- Frontend mới có smoke test; cần bổ sung test widget/service và kiểm thử tích hợp các luồng đăng nhập, OTP, chuyển khoản, lịch sử, lỗi mạng.
- Cần chạy xác minh sau các thay đổi gần nhất: test backend trong Docker, `flutter analyze`, `flutter test`, và thao tác chuyển khoản bằng tài khoản demo rồi mở lịch sử.
- Trước production cần cấu hình TLS/HTTPS, secret riêng, CORS theo domain, nhà cung cấp OTP thật, rate limit/monitoring/backup và rà soát bảo mật/nghiệp vụ. README có thêm mục production readiness.

## Seed tài khoản demo

Compose bật `SEED_DEMO_DATA=true` mặc định. Seed hiện khai báo:

| Người dùng | Tài khoản | Số dư mở đầu | Mật khẩu mặc định |
| --- | --- | ---: | --- |
| `alice.demo@banking.local` | `100000000001` | 1.000.000 VND | `DemoCustomer123!` |
| `bob.demo@banking.local` | `100000000002` | 500.000 VND | `DemoCustomer123!` |

Seed admin mặc định trong Compose là `admin@banking.local` / `ChangeThisAdminPassword123!`. Hãy xem đây là thông tin local dành cho demo; thay đổi trong `.env` nếu cần. Không dùng mật khẩu mẫu ngoài môi trường local.

## Khởi động local nhanh

Từ thư mục gốc repo, dùng PowerShell:

```powershell
Copy-Item .env.example .env # chỉ làm nếu chưa có .env
docker compose up --build -d
Invoke-RestMethod http://127.0.0.1:8000/health
```

Frontend ở terminal khác:

```powershell
Set-Location app
flutter pub get
flutter run -d chrome
```

Mở Mailpit tại `http://127.0.0.1:8025` để lấy OTP. Xem thêm hướng dẫn chi tiết trong [`README.md`](../README.md) và [`app/FE_README.md`](../app/FE_README.md).

## Chạy backend tests

Từ thư mục gốc repo, database test chạy riêng bằng profile `test`:

```powershell
docker compose --profile test up -d postgres-test
docker compose run --rm `
  -e PYTHONPATH=/code `
  -e SEED_DEMO_DATA=false `
  -e TEST_DATABASE_URL=postgresql+psycopg://banking_test:banking_test_password@postgres-test:5432/banking_test `
  api pytest -q
```

Không trỏ `TEST_DATABASE_URL` vào database phát triển. Lệnh kiểm tra trên được ghi để tham khảo; trạng thái tài liệu không khẳng định rằng test đã chạy thành công sau các thay đổi gần nhất.

## Nơi bắt đầu khi tiếp tục phát triển

1. Đọc file này và [`README.md`](../README.md), sau đó kiểm tra `git status` để giữ nguyên các thay đổi đang có.
2. Khởi động stack local, xác nhận `/health`, rồi kiểm tra login/OTP và chuyển khoản giữa Alice/Bob.
3. Mở lịch sử sau chuyển khoản để xác nhận giao dịch hiển thị, số tiền và chiều giao dịch đúng.
4. Chạy backend tests và Flutter analyze/test; xử lý lỗi trước khi mở rộng chức năng.
5. Khi tiếp tục tính năng: cân nhắc màn hình admin và mở rộng test. Không bắt đầu interbank trừ khi phạm vi được đổi.
