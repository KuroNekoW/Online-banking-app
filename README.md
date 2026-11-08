Note: README.txt để mô tả step by step cho ae đọc để update tình hình, cái README này để làm production

# Online Banking App

Hệ thống ngân hàng trực tuyến trên di động (đồ án SE113), gồm ứng dụng **Flutter**, API **FastAPI** và cơ sở dữ liệu **PostgreSQL**. Hệ thống hỗ trợ đăng ký có xác thực OTP, quản lý tài khoản và lịch sử giao dịch, quản lý người thụ hưởng, chuyển khoản nội bộ có xác nhận OTP, thông báo và các chức năng quản trị.

> **Phạm vi:** Dự án mô phỏng nghiệp vụ ngân hàng cho mục đích học tập và phát triển local. Không kết nối ngân hàng thật, không xử lý tiền thật. Xem [Production readiness](#production-readiness) trước khi cân nhắc triển khai.

## Mục lục

- [Kiến trúc](#kiến-trúc)
- [Công nghệ](#công-nghệ)
- [Cấu trúc repository](#cấu-trúc-repository)
- [Yêu cầu hệ thống](#yêu-cầu-hệ-thống)
- [Khởi chạy nhanh](#khởi-chạy-nhanh)
- [Cấu hình](#cấu-hình)
- [Backend](#backend)
- [Frontend](#frontend)
- [Dữ liệu demo](#dữ-liệu-demo)
- [Quy tắc nghiệp vụ và bảo mật](#quy-tắc-nghiệp-vụ-và-bảo-mật)
- [Kiểm thử](#kiểm-thử)
- [Vận hành và xử lý sự cố](#vận-hành-và-xử-lý-sự-cố)
- [Production readiness](#production-readiness)
- [Tài liệu liên quan](#tài-liệu-liên-quan)

## Kiến trúc

```text
Flutter client ──HTTPS/JSON──▶ FastAPI ──▶ PostgreSQL
 (app/)                        (backend/)      ▲
                                  │            └── Alembic migrations
                                  └── SMTP ──▶ Mailpit (dev) / nhà cung cấp email-SMS (prod)
```

| Thành phần | Trách nhiệm |
| --- | --- |
| **Flutter client** | Giao diện đa nền tảng (Web, Android, Windows); quản lý trạng thái bằng Provider |
| **FastAPI** | Xác thực, nghiệp vụ tài khoản, chuyển khoản, quản trị; tài liệu OpenAPI tại `/docs` |
| **PostgreSQL** | Lưu người dùng, tài khoản, bút toán sổ cái, người thụ hưởng, nhật ký kiểm toán |
| **Alembic** | Quản lý phiên bản schema; migration được áp dụng khi API khởi động |
| **Mailpit** | SMTP sandbox cho môi trường dev, dùng để xem OTP |

## Công nghệ

| Lớp | Stack |
| --- | --- |
| Frontend | Flutter, Dart (SDK ≥ 3.0.0), Material, Provider, `http`, `shared_preferences`, `intl` |
| Backend | Python 3.13, FastAPI, Uvicorn, Pydantic Settings |
| Dữ liệu | PostgreSQL 16, SQLAlchemy 2, psycopg 3, Alembic |
| Bảo mật | PyJWT (access/refresh token), Argon2 (băm mật khẩu) |
| Hạ tầng | Docker, Docker Compose |
| Kiểm thử | pytest, HTTPX (backend); `flutter test` (frontend) |

Phiên bản thư viện Python được ghim trong `backend/requirements.txt`.

## Cấu trúc repository

```text
Online-banking-app/
├── app/                  # Flutter client
│   ├── lib/
│   │   ├── core/         # Cấu hình API, mạng, lưu trữ, theme, tiện ích
│   │   ├── models/       # Domain models
│   │   ├── providers/    # State management (auth, banking)
│   │   ├── screens/      # Màn hình
│   │   ├── services/     # API client (auth, banking, transfer)
│   │   └── widgets/      # Component dùng lại
│   ├── test/
│   └── FE_README.md      # Tài liệu chi tiết frontend
├── backend/
│   ├── app/
│   │   ├── api/          # Endpoint FastAPI
│   │   ├── core/         # Cấu hình, bảo mật
│   │   ├── db/           # Session và mô hình SQLAlchemy
│   │   ├── schemas/      # Pydantic request/response
│   │   ├── scripts/      # Seed dữ liệu
│   │   └── services/     # Nghiệp vụ (OTP, email, ...)
│   ├── alembic/          # Migrations
│   ├── tests/
│   ├── main.py
│   ├── requirements.txt
│   └── Dockerfile
├── docs/                 # Đặc tả yêu cầu, ERD
├── .env.example
└── docker-compose.yml
```

## Yêu cầu hệ thống

| Công cụ | Dùng cho | Ghi chú |
| --- | --- | --- |
| Docker Desktop / Docker Engine + Compose v2 | Backend, PostgreSQL, Mailpit | Bắt buộc. Không cần cài Python hay PostgreSQL trên host |
| Flutter SDK (stable, tương thích Dart ≥ 3.0.0) | Frontend | Xác minh bằng `flutter doctor` |
| Google Chrome | Chạy Flutter Web | Target mặc định cho phát triển |
| Android Studio + SDK | Chạy Android | Tùy chọn |
| Toolchain Windows desktop | Chạy Windows | Tùy chọn |

## Khởi chạy nhanh

Các lệnh dưới đây viết cho PowerShell; trên Linux/macOS dùng `cp` thay cho `Copy-Item`.

```powershell
# 1. Tạo cấu hình môi trường (không ghi đè nếu .env đã tồn tại)
Copy-Item .env.example .env

# 2. Khởi chạy backend stack (API + PostgreSQL + Mailpit)
docker compose up --build -d

# 3. Kiểm tra
Invoke-RestMethod http://127.0.0.1:8000/health      # { "status": "ok" }

# 4. Chạy client
Set-Location app
flutter pub get
flutter run -d chrome
```

| Endpoint | URL |
| --- | --- |
| API | `http://127.0.0.1:8000` |
| OpenAPI / Swagger | `http://127.0.0.1:8000/docs` |
| Health check | `http://127.0.0.1:8000/health` |
| Mailpit (OTP dev) | `http://127.0.0.1:8025` |

Khi khởi động, API tự động áp dụng migration Alembic và (nếu bật) nạp dữ liệu demo.

## Cấu hình

Cấu hình được nạp từ biến môi trường, mẫu tại `.env.example`. Docker Compose đọc file `.env` ở thư mục gốc.

| Biến | Mô tả |
| --- | --- |
| `JWT_SECRET_KEY` | Khóa ký token. Phải dài, ngẫu nhiên, duy nhất cho từng môi trường |
| Thông tin PostgreSQL | User, mật khẩu, tên database cho service `postgres` |
| `SEED_DEMO_DATA` | `true` để nạp dữ liệu demo khi khởi động; phải là `false` ngoài môi trường dev |
| Cấu hình SMTP | Host/port của dịch vụ gửi OTP (mặc định trỏ tới Mailpit) |

Yêu cầu bắt buộc:

- Không commit `.env` hoặc bất kỳ secret nào lên Git.
- Không dùng giá trị mẫu trong `.env.example` ở bất kỳ môi trường nào ngoài local.
- Đặt `SEED_DEMO_DATA=false` rồi tạo lại container (`docker compose up -d --force-recreate api`) để tắt seed. Thao tác này không xóa dữ liệu đã có.

## Backend

### Vận hành bằng Docker Compose

```powershell
docker compose up --build -d      # khởi chạy / cập nhật
docker compose ps                 # trạng thái dịch vụ
docker compose logs -f api        # theo dõi log API
docker compose down               # dừng, giữ nguyên volume dữ liệu
```

> `docker compose down -v` xóa volume và toàn bộ dữ liệu database local. Chỉ dùng khi chủ ý reset.

### Migration

Schema được quản lý hoàn toàn bằng Alembic:

- Mọi thay đổi schema phải đi kèm một migration **mới**; không sửa migration đã được chia sẻ.
- Cập nhật test tương ứng và chạy lại toàn bộ bộ test backend trước khi merge.

### Nhóm API

`/docs` là nguồn tham chiếu chính xác cho request/response.

| Nhóm | Chức năng |
| --- | --- |
| Hệ thống | `GET /health` |
| Xác thực | Đăng ký, xác thực/gửi lại OTP, đăng nhập, refresh/logout, đặt lại và đổi mật khẩu |
| Khách hàng | Hồ sơ, tài khoản và số dư, người thụ hưởng, lịch sử giao dịch, thông báo |
| Chuyển khoản | Tạo, xác nhận OTP, xác thực, tra cứu |
| Quản trị | Danh sách/chi tiết khách hàng, khóa/mở khóa, phân quyền, nhật ký kiểm toán |

## Frontend

Chi tiết xem [`app/FE_README.md`](app/FE_README.md).

```powershell
Set-Location app
flutter pub get
flutter run -d chrome        # hoặc: -d windows | thiết bị/emulator Android
```

### Base URL của API theo nền tảng

Giá trị mặc định khai báo tại `app/lib/core/constants/api_constants.dart`.

| Nền tảng | Base URL |
| --- | --- |
| Web / Windows | `http://127.0.0.1:8000` |
| Android Emulator | `http://10.0.2.2:8000` |
| Thiết bị thật | `http://<IP-LAN-của-máy-chủ>:8000` (cùng mạng, firewall cho phép cổng 8000) |

CORS của API chỉ chấp nhận origin `localhost` / `127.0.0.1`. Không public API ra Internet khi chạy cấu hình dev.

## Dữ liệu demo

Khi `SEED_DEMO_DATA=true`, hệ thống tạo hai khách hàng (seed idempotent, không cộng dồn khi khởi động lại):

| Email | Mật khẩu | Số tài khoản | Số dư ban đầu |
| --- | --- | --- | ---: |
| `alice.demo@banking.local` | `DemoCustomer123!` | `100000000001` | 1.000.000 VND |
| `bob.demo@banking.local` | `DemoCustomer123!` | `100000000002` | 500.000 VND |

OTP (đăng ký, xác nhận chuyển khoản) được gửi tới Mailpit tại `http://127.0.0.1:8025`. Không có email nào được gửi tới hộp thư thật.

## Quy tắc nghiệp vụ và bảo mật

Các ràng buộc sau là bất biến của hệ thống và phải được giữ khi thay đổi mã nguồn:

**Sổ cái**
- Số dư được suy ra từ `transaction_entries`; không lưu số dư có thể sửa trực tiếp trên tài khoản.
- Tổng bút toán của mỗi giao dịch đã ghi sổ bằng 0.
- Bút toán đã ghi sổ là bất biến; sửa sai bằng giao dịch đảo.

**Phân quyền và dữ liệu**
- Mọi truy vấn tài khoản, giao dịch, người thụ hưởng đều giới hạn theo người dùng đã xác thực; không tin `user_id` do client gửi.
- API quản trị kiểm tra quyền Admin ở phía server.
- Khóa khách hàng thu hồi toàn bộ phiên đăng nhập đang hoạt động.

**Thông tin xác thực**
- Mật khẩu băm bằng Argon2.
- OTP và refresh token chỉ lưu dạng hash.
- Không ghi OTP hoặc token vào log ở môi trường production.

## Kiểm thử

### Frontend

```powershell
Set-Location app
flutter analyze
flutter test
```

Hiện tại frontend mới có smoke test khởi tạo ứng dụng.

### Backend

Bộ test dùng database `banking_test` riêng (service `postgres-test`, map ra host cổng `5433`), chạy migration thật, làm sạch dữ liệu trước mỗi test case và giả lập dịch vụ gửi OTP.

```powershell
# Khởi động database test
docker compose --profile test up -d postgres-test

# Chạy test
docker compose run --rm `
  -e PYTHONPATH=/code `
  -e SEED_DEMO_DATA=false `
  -e TEST_DATABASE_URL=postgresql+psycopg://banking_test:banking_test_password@postgres-test:5432/banking_test `
  api pytest -q

# Dọn dẹp
docker compose --profile test rm -s -f postgres-test
```

Thêm `-vv -s` vào `pytest` để xem chi tiết từng test. Không trỏ `TEST_DATABASE_URL` vào database phát triển.

## Vận hành và xử lý sự cố

| Triệu chứng | Nguyên nhân thường gặp / Xử lý |
| --- | --- |
| `docker` không nhận diện, daemon không chạy | Docker Engine chưa khởi động; mở Docker Desktop, mở lại terminal |
| API từ chối kết nối / container thoát liên tục | Kiểm tra `docker compose logs --tail 100 api`; thường do PostgreSQL chưa healthy hoặc `.env` không khớp |
| `port is already allocated` | Xung đột cổng 8000, 5432, 5433 hoặc 8025; giải phóng cổng hoặc đổi port host trong `docker-compose.yml`/`.env` |
| Không nhận được OTP | Xác nhận Mailpit đang chạy (`docker compose ps`) và kiểm tra `http://127.0.0.1:8025` |
| Android Emulator không gọi được API | Dùng `10.0.2.2` thay cho `localhost`/`127.0.0.1` |
| Thiết bị thật không gọi được API | Dùng IP LAN, cùng mạng, firewall cho phép cổng 8000 |
| Lỗi CORS trên trình duyệt | Truy cập bằng origin `localhost`/`127.0.0.1` do `flutter run -d chrome` cung cấp |
| Flutter không thấy thiết bị | Chạy `flutter doctor` và `flutter devices` |

## Production readiness

Dự án **chưa** sẵn sàng cho production. Các hạng mục cần hoàn thành trước khi triển khai thực tế:

**Bảo mật và hạ tầng**
- Cấu hình production tách biệt: HTTPS/TLS, quản lý secret (vault/secret manager), giới hạn truy cập mạng, CORS theo domain thực.
- Thay Mailpit bằng nhà cung cấp email/SMS có xác thực; theo dõi và cảnh báo lỗi gửi OTP.
- Thực thi ngưỡng đăng nhập sai và khóa tài khoản theo cấu hình; rate limiting cho OTP và các endpoint nhạy cảm.
- Logging có cấu trúc, monitoring, sao lưu/khôi phục database, rà soát bảo mật độc lập.

**Nghiệp vụ**
- Hoàn thiện đối soát chuyển khoản liên ngân hàng (chuyển trạng thái chờ xử lý sang thành công/thất bại).
- Chuẩn hóa Pydantic response schema cho toàn bộ endpoint và validate đầu vào nhất quán.

**Chất lượng**
- Mở rộng test backend: refresh/logout, đặt lại mật khẩu, giới hạn OTP, thông báo, phân trang, phân quyền, audit log, trạng thái chuyển khoản liên ngân hàng.
- Bổ sung test giao diện và test tích hợp frontend–API (đăng ký, đăng nhập, chuyển khoản, lỗi mạng).
- Thiết lập CI: chạy test backend với PostgreSQL, `flutter analyze` và `flutter test` cho mỗi pull request.

## Tài liệu liên quan

- Frontend: [`app/FE_README.md`](app/FE_README.md)
- Đặc tả dự án: [`docs/docs.docx`](docs/docs.docx)
- Sơ đồ ERD (PlantUML): [`docs/database-erd.puml`](docs/database-erd.puml)