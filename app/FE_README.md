# Hướng dẫn chạy ứng dụng Flutter

Thư mục `app/` chứa frontend Flutter của dự án Mobile Online Banking. Ứng dụng gọi API FastAPI trong `../backend/`; PostgreSQL lưu dữ liệu và Mailpit nhận email OTP khi chạy local. Làm lần lượt các bước dưới đây để khởi động ứng dụng trên máy phát triển.

## 1. Cài công cụ cần thiết

Trên Windows, cài đặt:

1. **Git**, để lấy mã nguồn dự án.
2. **Flutter SDK** và thêm thư mục `flutter/bin` vào `PATH`. Làm theo [hướng dẫn cài Flutter trên Windows](https://docs.flutter.dev/get-started/install/windows).
3. **Android Studio**, nếu muốn chạy Android Emulator. Trong Android Studio, cài Android SDK và tạo máy ảo trong **Device Manager**.
4. **Docker Desktop**, nếu muốn chạy backend bằng Docker Compose như hướng dẫn bên dưới. Mở Docker Desktop và chờ Docker Engine khởi động xong.
5. **Google Chrome**, nếu muốn chạy frontend trên trình duyệt.

Mở PowerShell mới và kiểm tra Flutter:

```powershell
flutter --version
flutter doctor
```

`flutter doctor` cho biết thành phần nào còn thiếu. Để chạy trên Chrome, cần Flutter và Chrome; để chạy Android, cần thêm Android toolchain và một emulator hoặc thiết bị đã kết nối.

## 2. Mở đúng thư mục dự án

Mở PowerShell tại thư mục gốc đã tải về hoặc clone dự án:

```powershell
Set-Location 'D:\SE113\Project\Online-banking-app'
```

Kiểm tra thư mục hiện tại có các mục `app`, `backend` và file `docker-compose.yml`:

```powershell
Get-ChildItem
```

Nếu dự án nằm ở nơi khác, thay đường dẫn trong lệnh `Set-Location` bằng đường dẫn thực tế.

## 3. Khởi động backend, database và Mailpit

Frontend không tự chạy máy chủ API. Mở một cửa sổ PowerShell tại thư mục gốc dự án và chạy:

```powershell
docker compose up --build -d
```

Lần đầu chạy, Docker sẽ tải image và build API nên có thể mất vài phút. Kiểm tra các dịch vụ:

```powershell
docker compose ps
```

Chờ dịch vụ `postgres` ở trạng thái healthy và `api` đang chạy. Sau đó kiểm tra API:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

Kết quả mong đợi:

```text
status
------
ok
```

Có thể mở thêm `http://127.0.0.1:8000/docs` để xem API và `http://localhost:8025` để mở hộp thư OTP Mailpit. Giữ các dịch vụ Docker chạy trong suốt thời gian dùng frontend.

> Nếu máy đã có file `.env` ở thư mục gốc, giữ nguyên file đó. Nếu chưa có, có thể tạo cấu hình local từ mẫu bằng lệnh `Copy-Item .env.example .env`. Các giá trị mẫu chỉ dành cho phát triển local, không dùng khi triển khai thật.

## 4. Cài dependency Flutter

Mở **cửa sổ PowerShell thứ hai** tại thư mục gốc dự án và chạy:

```powershell
Set-Location 'D:\SE113\Project\Online-banking-app\app'
flutter pub get
```

Lệnh này tải các package được khai báo trong `pubspec.yaml`. Chỉ cần chạy lại khi dependency thay đổi hoặc sau khi lấy phiên bản mã nguồn mới.

## 5. Chạy frontend

### Cách A: Chạy trên Chrome (khuyến nghị cho lần đầu)

Trong cửa sổ PowerShell thứ hai, vẫn ở thư mục `app`, chạy:

```powershell
flutter run -d chrome
```

Flutter sẽ build ứng dụng, mở Chrome và in địa chỉ local trong terminal. Nếu lệnh báo không tìm thấy thiết bị Chrome, kiểm tra đã cài Chrome và chạy:

```powershell
flutter devices
```

### Cách B: Chạy trên Android Emulator

1. Mở Android Studio, vào **Device Manager** và khởi chạy một Android Emulator.
2. Trong PowerShell ở thư mục `app`, kiểm tra Flutter nhận emulator:

   ```powershell
   flutter devices
   ```
3. Chạy ứng dụng:

   ```powershell
   flutter run
   ```

Ứng dụng tự chọn `http://10.0.2.2:8000` cho Android Emulator để kết nối tới backend trên máy tính.

### Cách C: Chạy ứng dụng Windows

Nếu Flutter đã cài Windows desktop toolchain:

```powershell
flutter run -d windows
```

## 6. Tạo tài khoản và thử các chức năng

1. Trên màn hình đăng nhập, chọn đăng ký tài khoản và nhập email bạn có thể kiểm tra, số điện thoại, họ tên và mật khẩu.
2. Mở Mailpit tại `http://localhost:8025`, tìm email đăng ký mới nhất và lấy mã OTP.
3. Nhập OTP vào ứng dụng để hoàn tất đăng ký, rồi đăng nhập bằng email hoặc số điện thoại và mật khẩu vừa tạo.
4. Thử xem trang chủ, số dư, lịch sử; tạo người thụ hưởng hoặc bắt đầu chuyển khoản.
5. Khi xác nhận đăng ký, đặt lại mật khẩu hoặc xác thực chuyển khoản, lấy mã OTP tương ứng trong Mailpit.

Đây là môi trường mô phỏng; không sử dụng tiền thật. Dịch vụ chuyển khoản liên ngân hàng hiện được mô phỏng ở backend.

## 7. Chọn hoặc sửa địa chỉ API

Ứng dụng chọn địa chỉ mặc định dựa theo nền tảng:

| Nơi chạy frontend  | Địa chỉ API mặc định                                   |
| -------------------- | ------------------------------------------------------------ |
| Chrome / Flutter Web | `http://127.0.0.1:8000`                                    |
| Android Emulator     | `http://10.0.2.2:8000`                                     |
| Windows desktop      | `http://127.0.0.1:8000`                                    |
| Điện thoại thật  | IP LAN của máy tính, ví dụ `http://192.168.1.20:8000` |

Địa chỉ mặc định được khai báo trong `lib/core/constants/api_constants.dart`. Để đổi địa chỉ, nhấn biểu tượng cài đặt trên màn hình đăng nhập hoặc mở mục cấu hình máy chủ trong hồ sơ. Nhập **base URL** gồm giao thức, host và port, ví dụ `http://192.168.1.20:8000`; không thêm đường dẫn API như `/auth/login`. Địa chỉ tùy chỉnh được lưu trên thiết bị và sẽ được ưu tiên hơn địa chỉ mặc định.

Nếu dùng điện thoại thật, điện thoại và máy tính phải cùng mạng Wi-Fi; dùng IP LAN của máy tính, không dùng `127.0.0.1`. Có thể tìm IP IPv4 bằng:

```powershell
ipconfig
```

Nếu firewall chặn kết nối, cho phép ứng dụng/API sử dụng port `8000` trên mạng riêng. Không mở port này ra Internet.

## 8. Lỗi thường gặp

- **`Connection refused`, `SocketException` hoặc lỗi kết nối tới port 8000:** chạy `docker compose ps`; nếu API chưa chạy, xem log bằng `docker compose logs -f api`. Kiểm tra `http://127.0.0.1:8000/health` trước khi thử lại frontend.
- **Chrome báo CORS:** dùng bản backend hiện tại trong dự án và mở frontend qua địa chỉ local do `flutter run -d chrome` cung cấp. Backend cho phép origin local `localhost` và `127.0.0.1`. Nếu đã sửa cấu hình backend, khởi động lại API bằng `docker compose up --build -d api`.
- **Mở frontend qua HTTPS nhưng gọi API HTTP:** trình duyệt có thể chặn request do mixed content. Chạy frontend local bằng HTTP hoặc cấu hình HTTPS cho API.
- **Không nhận được OTP:** đảm bảo dịch vụ `mailpit` đang chạy trong `docker compose ps`, rồi kiểm tra `http://localhost:8025`. Email chỉ được giữ trong hộp thư local khi chạy môi trường này.
- **Điện thoại thật không kết nối được:** `127.0.0.1` trên điện thoại trỏ về chính điện thoại. Đặt API URL thành IP LAN của máy tính và kiểm tra cùng Wi-Fi/firewall.
- **Port 8000, 5432 hoặc 8025 đang được dùng:** dừng dịch vụ khác đang chiếm port hoặc đổi port cấu hình trong `.env`, sau đó khởi động lại Docker Compose.
- **Muốn dừng backend:** từ thư mục gốc, chạy `docker compose down`. Dữ liệu PostgreSQL được lưu trong Docker volume; không dùng `docker compose down -v` trừ khi chủ ý xóa dữ liệu local.

## 9. Dừng và chạy lại

Để dừng frontend, nhấn `q` trong terminal đang chạy `flutter run` (hoặc `Ctrl+C`). Để dừng các dịch vụ backend, mở PowerShell tại thư mục gốc và chạy:

```powershell
docker compose down
```

Lần sau có thể khởi động backend bằng `docker compose up -d`, sau đó vào `app/` và chạy lại `flutter run -d chrome` hoặc thiết bị mong muốn.

## 10. Cấu trúc frontend

```text
lib/
  core/       Cấu hình API, HTTP client, lưu trữ, giao diện và định dạng
  models/     Model người dùng, tài khoản, người thụ hưởng và giao dịch
  providers/  Trạng thái đăng nhập và dữ liệu ngân hàng (Provider)
  screens/    Màn hình xác thực, trang chủ, chuyển khoản và hồ sơ
  services/   Lời gọi API xác thực, ngân hàng và chuyển khoản
  widgets/    Thành phần giao diện dùng lại
test/         Flutter widget tests
```

## 11. Kiểm tra frontend

Chạy từ thư mục `app/`:

```powershell
flutter analyze
flutter test
```

Test Flutter hiện là smoke test kiểm tra ứng dụng khởi tạo. Các kiểm thử API nằm riêng trong `../backend/tests/`.
