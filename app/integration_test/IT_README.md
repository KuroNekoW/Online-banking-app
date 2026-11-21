# Hướng dẫn Kiểm thử Tự động & Kiểm thử Tích hợp (Lab 3 - Nhóm 5)

Tài liệu này hướng dẫn chi tiết cách thực thi các bộ kiểm thử tự động (Automation Testing) và kiểm thử tích hợp (Integration Testing) trực tiếp trên ứng dụng Mobile Banking (Flutter). Kết quả kiểm thử được tự động tổng hợp và xuất ra file Excel (`.xlsx`) làm minh chứng phục vụ đồ án môn **Kiểm chứng phần mềm (SE113.R11)**.

---

## 1. Giới thiệu & Mục tiêu kiểm thử

Bộ kiểm thử được thiết kế để giải quyết trọn vẹn yêu cầu **Lab 3**: thay vì chỉ chạy kiểm thử trên các công cụ riêng biệt (như NUnit trên console C#), toàn bộ thuật toán kiểm thử ngày tháng cùng các luồng xử lý giao diện thực tế được đưa trực tiếp vào ứng dụng Flutter:

* **Tích hợp thuật toán Lab 2 vào App**: Kiểm chứng tính đúng đắn của hai hàm logic `dayInMonth` và `checkDate` trong `lib/core/utils/calendar_date_validator.dart`.
* **Kiểm thử tích hợp giao diện (UI Integration)**: Kiểm tra widget đồng hồ thời gian thực (`HomeScreen`), bộ lọc lịch sử giao dịch theo khoảng ngày (`TransactionHistoryScreen`), cơ chế xác thực ràng buộc ngày hợp lệ và định dạng hiển thị tiền tệ VND.
* **Tự động xuất báo cáo Excel (`.xlsx`)**: Sau khi hoàn thành các ca kiểm thử, hệ thống tự động sinh báo cáo chuẩn hóa gồm 2 sheet (**Tổng quan** và **Chi tiết kết quả**) phục vụ nộp bài và đối soát.

---

## 2. Phương pháp thực thi kiểm thử

Hệ thống hỗ trợ 2 phương pháp chạy kiểm thử tùy theo mục đích:

### Cách 1: Chạy kiểm thử tự động toàn diện & Xuất Excel (Khuyến nghị)

> [!TIP]
> **Ưu điểm**: Chạy siêu nhanh, độc lập, không cần cài đặt WebDriver bên ngoài hay trình biên dịch C++ Desktop, đồng thời tự động xuất đầy đủ 72 ca kiểm thử vào file Excel.

1. Mở terminal (PowerShell) và chuyển vào thư mục `app`:
   ```powershell
   cd D:\SE113\Project\Online-banking-app\app
   ```

2. Đảm bảo đã cài đủ thư viện:
   ```powershell
   D:\flutter\bin\flutter.bat pub get
   ```

3. Chạy toàn bộ bộ kiểm thử tự động Lab 3:
   ```powershell
   D:\flutter\bin\flutter.bat test test/lab3_automation_app_test.dart
   ```

4. **Kết quả đạt được**:
   * Chạy thành công **72/72 ca kiểm thử** (100% Passed).
   * Tự động sinh file báo cáo Excel:
     * `app/integration_test/reports/Lab3_Automation_App_Test_Report.xlsx`
     * `../../lab3/SE113.R11_Nhóm 5_Lab3/TestResults/Lab3_Automation_App_Test_Report.xlsx`

---

### Cách 2: Chạy kiểm thử E2E tương tác trực quan qua WebDriver (Live Backend)

Phương pháp này dùng Flutter Driver để khởi chạy ứng dụng trực quan trên trình duyệt (Chrome/Edge) hoặc thiết bị/emulator, tự động điền form đăng nhập, gọi API backend thật và thao tác lọc ngày.

#### Bước chuẩn bị:
1. **Khởi động Backend và dữ liệu mẫu**:
   ```powershell
   cd D:\SE113\Project\Online-banking-app
   docker compose up -d
   ```
   Đảm bảo backend chạy tại `http://127.0.0.1:8000` và tài khoản demo `alice.demo@banking.local` sẵn sàng.

2. **Khởi chạy WebDriver tương ứng**:
   * **Với Google Chrome**: Tải ChromeDriver phù hợp phiên bản Chrome, mở terminal riêng và chạy:
     ```powershell
     chromedriver.exe --port=4444
     ```
   * **Với Microsoft Edge**: Tải Edge WebDriver (từ Microsoft Edge Developer), mở terminal riêng và chạy:
     ```powershell
     msedgedriver.exe --port=4444
     ```

#### Lệnh thực thi:
Tại thư mục `D:\SE113\Project\Online-banking-app\app`, mở một terminal khác và chạy:

* **Trên Google Chrome**:
  ```powershell
  D:\flutter\bin\flutter.bat drive `
    --driver=test_driver/integration_test.dart `
    --target=integration_test/transaction_history_datetime_test.dart `
    -d chrome `
    --dart-define=BANKING_TEST_API_URL=http://127.0.0.1:8000 `
    --dart-define=BANKING_TEST_EMAIL=alice.demo@banking.local `
    --dart-define=BANKING_TEST_PASSWORD=DemoCustomer123!
  ```

* **Trên Microsoft Edge**:
  ```powershell
  D:\flutter\bin\flutter.bat drive `
    --driver=test_driver/integration_test.dart `
    --target=integration_test/transaction_history_datetime_test.dart `
    -d edge `
    --browser-name=edge `
    --dart-define=BANKING_TEST_API_URL=http://127.0.0.1:8000 `
    --dart-define=BANKING_TEST_EMAIL=alice.demo@banking.local `
    --dart-define=BANKING_TEST_PASSWORD=DemoCustomer123!
  ```

---

## 3. Danh mục các ca kiểm thử (Test Matrix)

Bộ kiểm thử bao gồm tổng cộng **72 test cases** được đánh mã chi tiết:

| Nhóm kiểm thử | Mã Test Case | Số lượng | Mô tả nội dung kiểm thử |
| :--- | :--- | :---: | :--- |
| **DayInMonth Algorithm** | `UT-D01` $\rightarrow$ `UT-D30` | 30 | Kiểm thử thuật toán số ngày trong tháng: các tháng 30, 31 ngày, năm thường, năm nhuận, năm thế kỷ chia hết 400 (2000, 2400), năm thế kỷ không nhuận (1900, 2100) và các ca biên âm/ngoài dải. |
| **CheckDate Algorithm** | `UT-C01` $\rightarrow$ `UT-C38` | 38 | Kiểm thử tính hợp lệ của bộ 3 giá trị (ngày, tháng, năm): ngày hợp lệ, ngày vượt quá cận trên từng tháng, ngày nhuận không hợp lệ, ngày biên ngoài giới hạn (ngày 0, ngày 32, tháng 13,...). |
| **App UI Integration** | `IT-APP-01` | 1 | Kiểm tra widget hiển thị thứ, ngày và giờ thời gian thực trên trang chủ (`HomeScreen`). |
| **App UI Integration** | `IT-APP-02` | 1 | Kiểm tra điều hướng sang tab Lịch sử và sự sẵn sàng của bộ lọc ngày (`history-start-date`, `history-end-date`, nút Áp dụng). |
| **App UI Integration** | `IT-APP-03` | 1 | Kiểm tra cơ chế ràng buộc và xác thực tính hợp lệ của khoảng ngày khi người dùng áp dụng lọc. |
| **App UI Integration** | `IT-APP-04` | 1 | Kiểm tra hàm định dạng tiền tệ và hiển thị thẻ giao dịch (`TransactionTile`) chuẩn format VND. |

---

## 4. Cấu trúc Báo cáo Excel Minh chứng

Sau mỗi lần chạy, file `Lab3_Automation_App_Test_Report.xlsx` được tự động cập nhật với 2 Sheet:

1. **Sheet 1: `Tổng quan`**
   * Tiêu đề: `BÁO CÁO KIỂM THỬ TỰ ĐỘNG LAB 3 - TRÊN MOBILE BANKING APP`
   * Môn học: `Kiểm chứng phần mềm (SE113.R11) - Nhóm 5`
   * Thời gian thực thi (Timestamp chính xác).
   * Tổng số ca: **72** | Số ca Đạt: **72** | Số ca Thất bại: **0** | Tỷ lệ thành công: **100.0%**.
   * Kết luận chung: **TẤT CẢ KIỂM THỬ ĐẠT (PASSED)**.

2. **Sheet 2: `Chi tiết kết quả`**
   * `Mã Test Case`: Định danh ca kiểm thử (`UT-D01`..`UT-D30`, `UT-C01`..`UT-C38`, `IT-APP-01`..`IT-APP-04`).
   * `Phân hệ / Chức năng`: Module đang kiểm thử.
   * `Nội dung kiểm thử`: Tóm tắt kịch bản.
   * `Dữ liệu đầu vào`: Tham số ngày, tháng, năm hoặc thao tác người dùng.
   * `Kết quả mong đợi`: Output chuẩn theo đặc tả Lab 2 & Lab 3.
   * `Kết quả thực tế`: Giá trị trả về từ ứng dụng.
   * `Trạng thái`: **Đạt** / Không đạt.
   * `Thời gian (ms)`: Thời gian thực thi từng ca.
   * `Ghi chú`: Thông tin bổ sung nếu có.
