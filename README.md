# Hệ thống Ngân hàng Trực tuyến trên Di động

Đây là đồ án SE113 xây dựng một ứng dụng ngân hàng trực tuyến mô phỏng. Dự án gồm ứng dụng Flutter, API FastAPI và cơ sở dữ liệu PostgreSQL. Người dùng có thể đăng ký, xác thực OTP, xem tài khoản và lịch sử giao dịch, quản lý người thụ hưởng, thực hiện chuyển khoản nội bộ và nhận thông báo.

> **Lưu ý:** Đây là sản phẩm phục vụ học tập và phát triển local, không kết nối ngân hàng thật, không xử lý tiền thật và chưa sẵn sàng cho môi trường production.

## Mục lục

- [Tổng quan kiến trúc](#tổng-quan-kiến-trúc)
- [Cấu trúc thư mục](#cấu-trúc-thư-mục)
- [Môi trường và công nghệ](#môi-trường-và-công-nghệ)
- [Cài đặt công cụ](#cài-đặt-công-cụ)
- [Chạy toàn bộ dự án lần đầu](#chạy-toàn-bộ-dự-án-lần-đầu)
- [Chạy ứng dụng Flutter](#chạy-ứng-dụng-flutter)
- [Tài khoản demo và OTP](#tài-khoản-demo-và-otp)
- [Chạy kiểm thử](#chạy-kiểm-thử)
- [Lỗi thường gặp](#lỗi-thường-gặp)
- [Hướng cải thiện](#hướng-cải-thiện)

## Tổng quan kiến trúc

```text
Flutter (app/)  ── HTTP/JSON ──>  FastAPI (backend/)  ──>  PostgreSQL
                                       │
                                       └── SMTP local ──> Mailpit (email OTP)
```

- **Flutter** cung cấp giao diện trên trình duyệt Chrome, Android và Windows.
- **FastAPI** cung cấp API đăng nhập, tài khoản, người thụ hưởng, chuyển khoản và quản trị. Có thể xem danh sách API tại `http://127.0.0.1:8000/docs`.
- **PostgreSQL** lưu thông tin người dùng, tài khoản và các bút toán.
- **Alembic** tự chạy các bản migration để tạo/cập nhật cấu trúc cơ sở dữ liệu khi API khởi động.
- **Mailpit** nhận email OTP trong môi trường local. Email không được gửi đến hộp thư thật.
- **Docker Compose** khởi chạy API, PostgreSQL và Mailpit cùng lúc, không cần cài PostgreSQL hay Python riêng để chạy ứng dụng.

## Cấu trúc thư mục

```text
Online-banking-app/
├── app/                         # Ứng dụng giao diện Flutter
│   ├── lib/
│   │   ├── core/                # Cấu hình API, mạng, lưu trữ, giao diện và tiện ích
│   │   ├── models/              # Các đối tượng dữ liệu như tài khoản, giao dịch, người dùng
│   │   ├── providers/           # Quản lý trạng thái đăng nhập và dữ liệu ngân hàng
│   │   ├── screens/             # Các màn hình trong ứng dụng
│   │   ├── services/            # Gọi API xác thực, ngân hàng và chuyển khoản
│   │   ├── widgets/             # Thành phần giao diện có thể dùng lại
│   │   └── main.dart            # Điểm bắt đầu ứng dụng Flutter
│   ├── test/                    # Kiểm thử Flutter
│   ├── android/, windows/, web/ # Cấu hình chạy trên từng nền tảng
│   ├── pubspec.yaml             # Dependency và cấu hình Flutter
│   └── FE_README.md             # Hướng dẫn chi tiết riêng cho frontend
├── backend/
│   ├── app/
│   │   ├── api/                 # Các endpoint FastAPI
│   │   ├── core/                # Cấu hình và tiện ích bảo mật
│   │   ├── db/                  # Kết nối và mô hình SQLAlchemy
│   │   ├── schemas/             # Cấu trúc dữ liệu đầu vào/đầu ra API
│   │   ├── scripts/             # Lệnh khởi tạo dữ liệu mẫu
│   │   └── services/            # Nghiệp vụ như OTP và gửi email
│   ├── alembic/                 # Quản lý phiên bản cấu trúc database
│   ├── tests/                   # Kiểm thử API và nghiệp vụ backend
│   ├── main.py                  # Khởi tạo FastAPI và đăng ký router
│   ├── requirements.txt         # Các thư viện Python
│   └── Dockerfile               # Cách đóng gói backend thành Docker image
├── docs/                        # Tài liệu yêu cầu và sơ đồ cơ sở dữ liệu
├── .env.example                 # Mẫu biến môi trường cho Docker Compose
└── docker-compose.yml           # Khai báo các dịch vụ chạy local
```

## Môi trường và công nghệ

| Thành phần                | Công nghệ                                | Vai trò                                                              |
| --------------------------- | ------------------------------------------ | --------------------------------------------------------------------- |
| Frontend                    | Flutter, Dart, Material, Provider          | Giao diện và quản lý trạng thái                                 |
| HTTP và lưu trữ frontend | `http`, `shared_preferences`, `intl` | Gọi API, lưu tùy chọn/phiên đăng nhập, định dạng dữ liệu |
| Backend                     | Python 3.13, FastAPI, Uvicorn              | Xây dựng và chạy API                                              |
| Kiểm tra dữ liệu         | Pydantic Settings, Email Validator         | Cấu hình môi trường và xác thực dữ liệu                     |
| Cơ sở dữ liệu           | PostgreSQL 16, SQLAlchemy 2, psycopg 3     | Lưu dữ liệu và truy vấn                                          |
| Migration                   | Alembic                                    | Tạo và cập nhật schema                                            |
| Bảo mật                   | PyJWT, Argon2                              | Token xác thực và băm mật khẩu                                  |
| Email phát triển          | Mailpit                                    | Hộp thư local để xem OTP                                          |
| Đóng gói                 | Docker, Docker Compose                     | Chạy backend và dịch vụ phụ trợ                                 |
| Kiểm thử backend          | pytest, HTTPX                              | Kiểm thử API và nghiệp vụ                                        |

Phiên bản Python trong image backend là **3.13**. `pubspec.yaml` khai báo Dart SDK từ `3.0.0` trở lên; nên cài Flutter SDK ổn định mới nhất tương thích với phiên bản Dart đó. Phiên bản thư viện Python cụ thể được ghim trong `backend/requirements.txt`.

## Cài đặt công cụ

Các hướng dẫn lệnh bên dưới sử dụng **Windows PowerShell**.

### Công cụ cần thiết

1. **Git** (tùy chọn nếu bạn đã có mã nguồn): cài từ [git-scm.com](https://git-scm.com/download/win).
2. **Docker Desktop**: cài từ [docker.com](https://www.docker.com/products/docker-desktop/). Mở Docker Desktop và chờ Docker Engine khởi động hoàn tất. Docker Desktop sẽ chạy API, PostgreSQL và Mailpit.
3. **Flutter SDK**: cài theo [hướng dẫn chính thức cho Windows](https://docs.flutter.dev/get-started/install/windows), rồi thêm thư mục `flutter\bin` vào biến môi trường `Path`.
4. **Google Chrome**: cần nếu muốn chạy ứng dụng trên Chrome. Đây là cách đơn giản nhất để bắt đầu.
5. **Android Studio** (chỉ khi muốn chạy Android): cài Android SDK và tạo máy ảo trong **Device Manager**.

Không cần cài Python, PostgreSQL hay Mailpit riêng nếu chạy backend bằng Docker Compose.

### Kiểm tra công cụ

Mở **PowerShell mới** sau khi cài Flutter để cập nhật `Path`, rồi chạy:

```powershell
git --version
docker --version
docker compose version
flutter --version
flutter doctor
```

`flutter doctor` hiển thị những thành phần Flutter còn thiếu. Chạy trên Chrome chỉ cần Flutter và Chrome; chạy Android cần thêm Android toolchain và emulator/thiết bị. Nếu PowerShell báo không nhận ra `flutter` hoặc `docker`, kiểm tra lại cài đặt/`Path` và khởi động lại terminal hoặc Docker Desktop.

## Chạy toàn bộ dự án lần đầu

### Bước 1: Mở thư mục dự án

Nếu dự án nằm ở đường dẫn mặc định trong máy của bạn:

```powershell
Set-Location 'D:\SE113\Project\Online-banking-app'
```

Nếu bạn đã tải/cloned dự án ở nơi khác, thay đường dẫn trên bằng đường dẫn thực tế. Kiểm tra đang ở đúng thư mục:

```powershell
Get-ChildItem
```

Bạn cần thấy `app`, `backend`, `docker-compose.yml` và `.env.example`.

### Bước 2: Tạo cấu hình local

Tạo file cấu hình từ mẫu:

```powershell
Copy-Item .env.example .env
```

Mở `.env` bằng VS Code hoặc trình soạn thảo văn bản. Đặt mật khẩu database và `JWT_SECRET_KEY` riêng cho máy của bạn; secret nên dài, ngẫu nhiên và không được đưa lên Git. Các giá trị mẫu chỉ dùng để học/chạy local. Không dùng chúng khi triển khai thật.

Nếu `.env` đã tồn tại, không chạy lại lệnh copy để tránh ghi đè cấu hình của bạn. Docker Compose có giá trị mặc định để tiện chạy thử, nhưng nên tạo `.env` riêng trước khi sử dụng.

### Bước 3: Khởi chạy backend và các dịch vụ

Trong PowerShell tại thư mục gốc dự án, chạy:

```powershell
docker compose up --build -d
```

Lần đầu Docker cần tải image và cài các thư viện backend nên có thể mất vài phút. Lệnh này chạy ở chế độ nền. Kiểm tra trạng thái:

```powershell
docker compose ps
```

Đợi PostgreSQL healthy và API hoạt động, sau đó kiểm tra:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

Kết quả mong đợi có `status` là `ok`. Bạn cũng có thể mở:

- Tài liệu API: `http://127.0.0.1:8000/docs`
- Hộp thư OTP local: `http://127.0.0.1:8025`

API tự chạy Alembic migration và tạo dữ liệu seed khi khởi động. Nếu API chưa sẵn sàng, xem log bằng `docker compose logs -f api`; nhấn `Ctrl+C` để ngừng theo dõi log (không dừng container).

## Chạy ứng dụng Flutter

Giữ backend đang chạy. Mở **cửa sổ PowerShell thứ hai**, chuyển vào thư mục frontend và tải dependencies:

```powershell
Set-Location 'D:\SE113\Project\Online-banking-app\app'
flutter pub get
```

Nếu dự án nằm nơi khác, dùng đường dẫn thực tế tương ứng.

### Chạy trên Chrome (khuyến nghị)

```powershell
flutter run -d chrome
```

Flutter sẽ biên dịch ứng dụng và mở trình duyệt. Nếu không tìm thấy Chrome, kiểm tra Chrome đã cài chưa và xem thiết bị Flutter nhận diện được:

```powershell
flutter devices
```

### Chạy trên Android Emulator

1. Mở Android Studio và khởi động máy ảo từ **Device Manager**.
2. Trong terminal tại thư mục `app`, kiểm tra thiết bị:

   ```powershell
   flutter devices
   ```
3. Chạy ứng dụng:

   ```powershell
   flutter run
   ```

### Chạy trên Windows desktop

Cần cài Windows desktop toolchain theo hướng dẫn Flutter, sau đó chạy:

```powershell
flutter run -d windows
```

### Địa chỉ API theo nền tảng

| Nơi chạy ứng dụng | Địa chỉ API mặc định                                   |
| --------------------- | ------------------------------------------------------------ |
| Chrome / Flutter Web  | `http://127.0.0.1:8000`                                    |
| Windows desktop       | `http://127.0.0.1:8000`                                    |
| Android Emulator      | `http://10.0.2.2:8000`                                     |
| Điện thoại thật   | IP LAN của máy tính, ví dụ `http://192.168.1.20:8000` |

Các giá trị mặc định được khai báo trong `app/lib/core/constants/api_constants.dart`. Để dùng điện thoại thật, điện thoại và máy tính cần cùng mạng Wi-Fi; cấu hình base URL thành IP LAN của máy tính (có thể tìm bằng `ipconfig`), không dùng `127.0.0.1`. Không mở API ra Internet.

## Tài khoản demo và OTP

Compose bật dữ liệu demo mặc định (`SEED_DEMO_DATA=true`). Có thể đăng nhập bằng:

| Email                        | Mật khẩu           | Số tài khoản  | Số dư ban đầu |
| ---------------------------- | -------------------- | ---------------- | ----------------: |
| `alice.demo@banking.local` | `DemoCustomer123!` | `100000000001` |     1.000.000 VND |
| `bob.demo@banking.local`   | `DemoCustomer123!` | `100000000002` |       500.000 VND |

Hai tài khoản demo có thể chuyển khoản nội bộ cho nhau. Đây là dữ liệu local; không sử dụng thông tin này trên hệ thống thật. Dữ liệu seed không bị cộng lặp lại khi API khởi động lại. Để tắt việc tạo dữ liệu demo trong lần chạy sau, đặt `SEED_DEMO_DATA=false` trong `.env` rồi tạo lại container API:

```powershell
docker compose up -d --force-recreate api
```

Tắt seed không xóa dữ liệu demo đã có trong database.

OTP được gửi tới Mailpit thay vì email thật. Mở `http://localhost:8025`, tìm email mới nhất của tài khoản rồi nhập mã sáu chữ số vào ứng dụng. Luồng này áp dụng cho đăng ký và xác nhận chuyển khoản.

## Chạy kiểm thử

### Kiểm tra frontend

Từ thư mục `app/`:

```powershell
flutter analyze
flutter test
```

Test Flutter hiện có là smoke test kiểm tra ứng dụng khởi tạo.

### Kiểm thử backend

Từ thư mục gốc, khởi chạy PostgreSQL riêng dành cho test:

```powershell
docker compose --profile test up -d postgres-test
```

Sau đó chạy bộ test trong container backend. Test sử dụng database `banking_test` riêng ở port nội bộ `5432` của service `postgres-test`, được ánh xạ ra máy host ở port `5433`; không trỏ test vào database phát triển:

```powershell
docker compose run --rm -e PYTHONPATH=/code -e SEED_DEMO_DATA=false -e TEST_DATABASE_URL=postgresql+psycopg://banking_test:banking_test_password@postgres-test:5432/banking_test api pytest -q
```

Muốn xem tên từng test:

```powershell
docker compose run --rm -e PYTHONPATH=/code -e TEST_DATABASE_URL=postgresql+psycopg://banking_test:banking_test_password@postgres-test:5432/banking_test api pytest -vv -s
```

Test chạy migration thật, làm sạch dữ liệu trong database test trước mỗi trường hợp và thay dịch vụ gửi OTP bằng giả lập. Khi kiểm thử xong, có thể xóa container PostgreSQL test:

```powershell
docker compose --profile test rm -s -f postgres-test
```

## API và quy tắc nghiệp vụ quan trọng

Tài liệu OpenAPI tại `/docs` là nguồn tham khảo chính xác cho request/response.

| Nhóm          | Chức năng chính                                                                              |
| -------------- | ----------------------------------------------------------------------------------------------- |
| Hệ thống     | `GET /health`                                                                                 |
| Xác thực     | Đăng ký, xác thực/gửi lại OTP, đăng nhập, refresh/logout, đặt lại/đổi mật khẩu |
| Khách hàng   | Hồ sơ, tài khoản/số dư, người thụ hưởng, lịch sử giao dịch, thông báo           |
| Chuyển khoản | Tạo, xác nhận OTP, xác thực và tra cứu chuyển khoản                                    |
| Quản trị     | Danh sách/chi tiết khách hàng, khóa/mở khóa, phân quyền và nhật ký kiểm toán      |

Khi sửa phần chuyển khoản hoặc sổ cái, cần giữ các nguyên tắc sau:

- Số dư được tính từ `transaction_entries`; không thêm số dư có thể thay đổi trực tiếp trên tài khoản.
- Tổng các bút toán của một giao dịch đã ghi sổ phải bằng không. Sửa sai bằng giao dịch đảo, không chỉnh bút toán đã ghi sổ.
- Mọi dữ liệu tài khoản, giao dịch và người thụ hưởng phải được giới hạn theo người dùng đã xác thực; không tin `user_id` do client gửi.
- Khóa khách hàng phải thu hồi phiên đăng nhập đang hoạt động; API quản trị cần kiểm tra quyền Admin.
- OTP và refresh token được lưu dạng hash. Không trả hoặc ghi OTP vào log trong môi trường production.

## Lỗi thường gặp

| Lỗi / dấu hiệu                                    | Cách kiểm tra và xử lý                                                                                                                                                                        |
| ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `docker` không được nhận diện                | Mở Docker Desktop, chờ Engine chạy; mở PowerShell mới và thử `docker --version`.                                                                                                          |
| Docker daemon không chạy                           | Khởi động Docker Desktop rồi kiểm tra `docker compose ps`.                                                                                                                                  |
| API không phản hồi hoặc `Connection refused`   | Chạy `docker compose ps`, xem `docker compose logs -f api`, rồi thử lại `/health` khi API đã khởi động xong.                                                                        |
| Container API thoát liên tục                      | Xem log bằng `docker compose logs --tail 100 api`. Lỗi kết nối database thường do PostgreSQL chưa healthy hoặc cấu hình `.env` không khớp.                                         |
| `port is already allocated`                        | Một ứng dụng khác đang dùng port 8000, 5432, 5433 hoặc 8025. Dừng ứng dụng đó hoặc chỉnh port host trong `docker-compose.yml`/`.env` rồi chạy lại.                            |
| Không nhận được OTP                             | Kiểm tra `docker compose ps` có Mailpit đang chạy không, rồi xem `http://localhost:8025`. OTP local không được gửi đến email thật.                                               |
| Frontend không kết nối API trên Android Emulator | Dùng `http://10.0.2.2:8000`, không dùng `localhost` hoặc `127.0.0.1` trong emulator.                                                                                                     |
| Điện thoại thật không kết nối API             | Dùng IP LAN của máy tính, đảm bảo hai thiết bị chung Wi-Fi và firewall cho phép kết nối tới port 8000 trên mạng riêng.                                                            |
| Lỗi CORS trên trình duyệt                        | Dùng URL frontend local do `flutter run -d chrome` cung cấp; API hiện chỉ cho phép origin `localhost`/`127.0.0.1` trên HTTP(S).                                                        |
| Flutter không thấy thiết bị                      | Chạy `flutter doctor` và `flutter devices`; kiểm tra Chrome đã cài hoặc emulator đã khởi động.                                                                                     |
| Muốn khởi động lại từ đầu                    | Dùng `docker compose down` rồi `docker compose up --build -d`. Lệnh `down` giữ volume database; **không** dùng `docker compose down -v` trừ khi chủ ý xóa dữ liệu local. |

Kết thúc phiên làm việc, nhấn `q` hoặc `Ctrl+C` trong terminal đang chạy Flutter. Dừng các dịch vụ backend bằng lệnh tại thư mục gốc:

```powershell
docker compose down
```

## Hướng cải thiện

Các việc nên cân nhắc trước khi dùng dự án trong môi trường thực tế:

1. Bổ sung kiểm thử cho refresh/logout, đặt lại mật khẩu, giới hạn OTP, thông báo, phân trang, phân quyền, audit log và các trạng thái chuyển khoản liên ngân hàng.
2. Thực thi ngưỡng đăng nhập sai và khóa tài khoản theo cấu hình.
3. Thay Mailpit bằng nhà cung cấp email/SMS có xác thực; quản lý secret an toàn và bổ sung theo dõi lỗi gửi OTP.
4. Hoàn thiện đối soát cho chuyển khoản liên ngân hàng để cập nhật trạng thái đang chờ thành thành công hoặc thất bại.
5. Chuẩn hóa response schema Pydantic cho tất cả endpoint và bổ sung kiểm tra dữ liệu đầu vào nhất quán.
6. Thêm CI để chạy test backend với PostgreSQL và test/lint Flutter cho mỗi pull request.
7. Bổ sung cấu hình production riêng: HTTPS, secret management, logging/monitoring, sao lưu/khôi phục database, giới hạn truy cập và rà soát bảo mật.
8. Cải thiện test giao diện và tích hợp frontend với API cho các luồng đăng ký, đăng nhập, chuyển khoản và lỗi mạng.

Khi thay đổi schema, tạo migration Alembic mới thay vì sửa migration đã được dùng chung; cập nhật test tương ứng và chạy lại bộ kiểm thử backend.

## Tài liệu liên quan

- Hướng dẫn frontend chi tiết: [`app/FE_README.md`](app/FE_README.md)
- Đặc tả dự án: [`docs/docs.docx`](docs/docs.docx)
- Mã nguồn sơ đồ ERD: [`docs/database-erd.puml`](docs/database-erd.puml)
