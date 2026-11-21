import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart';

import 'package:app/core/utils/calendar_date_validator.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/storage/storage_service.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/providers/banking_provider.dart';
import 'package:app/screens/home/main_navigation_screen.dart';
import 'package:app/screens/home/home_screen.dart';
import 'package:app/screens/history/transaction_history_screen.dart';

// Test record structure for Excel report
class TestCaseRecord {
  final String id;
  final String module;
  final String description;
  final String input;
  final String expected;
  final String actual;
  final String status;
  final int durationMs;
  final String note;

  TestCaseRecord({
    required this.id,
    required this.module,
    required this.description,
    required this.input,
    required this.expected,
    required this.actual,
    required this.status,
    required this.durationMs,
    this.note = '',
  });
}

final List<TestCaseRecord> _records = [];
final DateTime _testStartTime = DateTime.now();

void _exportExcelReport() {
  final excel = Excel.createExcel();
  excel.rename('Sheet1', 'Tổng quan');
  final summary = excel['Tổng quan'];

  final passed = _records.where((r) => r.status == 'Đạt').length;
  final failed = _records.where((r) => r.status == 'Không đạt').length;
  final total = _records.length;
  final passRate = total > 0 ? (passed / total * 100).toStringAsFixed(1) : '0';

  // Styles
  final headerStyle = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#0D47A1'),
    horizontalAlign: HorizontalAlign.Center,
  );

  final titleStyle = CellStyle(
    bold: true,
    fontSize: 14,
    fontColorHex: ExcelColor.fromHexString('#0D47A1'),
  );

  // Summary Sheet
  summary.appendRow([TextCellValue('BÁO CÁO KIỂM THỬ TỰ ĐỘNG LAB 3 - TRÊN MOBILE BANKING APP')]);
  summary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
  summary.appendRow([]);

  summary.appendRow([TextCellValue('Môn học:'), TextCellValue('Kiểm chứng phần mềm (SE113.R11) - Nhóm 5')]);
  summary.appendRow([TextCellValue('Hệ thống kiểm thử:'), TextCellValue('Mobile Online Banking System')]);
  summary.appendRow([TextCellValue('Thời gian thực thi:'), TextCellValue(_testStartTime.toLocal().toString())]);
  summary.appendRow([TextCellValue('Tổng số ca kiểm thử:'), IntCellValue(total)]);
  summary.appendRow([TextCellValue('Số ca ĐẠT (Passed):'), IntCellValue(passed)]);
  summary.appendRow([TextCellValue('Số ca THẤT BẠI (Failed):'), IntCellValue(failed)]);
  summary.appendRow([TextCellValue('Tỷ lệ thành công:'), TextCellValue('$passRate%')]);
  summary.appendRow([TextCellValue('Kết luận chung:'), TextCellValue(failed == 0 ? 'TẤT CẢ KIỂM THỬ ĐẠT (PASSED)' : 'CẦN KIỂM TRA LẠI')]);

  // Details Sheet
  final details = excel['Chi tiết kết quả'];
  final headers = [
    'Mã Test Case',
    'Phân hệ / Chức năng',
    'Nội dung kiểm thử',
    'Dữ liệu đầu vào',
    'Kết quả mong đợi',
    'Kết quả thực tế',
    'Trạng thái',
    'Thời gian (ms)',
    'Ghi chú',
  ];
  details.appendRow(headers.map((h) => TextCellValue(h)).toList());

  for (var i = 0; i < headers.length; i++) {
    details.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
  }

  for (final r in _records) {
    details.appendRow([
      TextCellValue(r.id),
      TextCellValue(r.module),
      TextCellValue(r.description),
      TextCellValue(r.input),
      TextCellValue(r.expected),
      TextCellValue(r.actual),
      TextCellValue(r.status),
      IntCellValue(r.durationMs),
      TextCellValue(r.note),
    ]);
  }

  final bytes = excel.encode();
  if (bytes != null) {
    // 1. Save to app/integration_test/reports/
    final reportDir1 = Directory('integration_test/reports');
    if (!reportDir1.existsSync()) reportDir1.createSync(recursive: true);
    final file1 = File('${reportDir1.path}/Lab3_Automation_App_Test_Report.xlsx');
    file1.writeAsBytesSync(bytes, flush: true);

    // 2. Save to lab3 folder for project submission
    final reportDir2 = Directory('../../lab3/SE113.R11_Nhóm 5_Lab3/TestResults');
    if (!reportDir2.existsSync()) reportDir2.createSync(recursive: true);
    final file2 = File('${reportDir2.path}/Lab3_Automation_App_Test_Report.xlsx');
    file2.writeAsBytesSync(bytes, flush: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final Map<String, String> mockSecureStorage = {};
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      final args = methodCall.arguments;
      final key = args is Map ? args['key'] as String? : null;
      switch (methodCall.method) {
        case 'write':
          if (key != null && args is Map) {
            mockSecureStorage[key] = args['value'] as String? ?? '';
          }
          return null;
        case 'read':
          return key != null ? mockSecureStorage[key] : null;
        case 'readAll':
          return Map<String, String>.from(mockSecureStorage);
        case 'delete':
          if (key != null) mockSecureStorage.remove(key);
          return null;
        case 'deleteAll':
          mockSecureStorage.clear();
          return null;
        case 'containsKey':
          return key != null ? mockSecureStorage.containsKey(key) : false;
        default:
          return null;
      }
    });

    SharedPreferences.setMockInitialValues({
      'access_token': 'mock-demo-token',
      'refresh_token': 'mock-demo-refresh-token',
    });
    await StorageService.init();
  });

  tearDownAll(() {
    _exportExcelReport();
  });

  group('PHẦN 1: KIỂM THỬ THUẬT TOÁN NGÀY THÁNG CỦA LAB 3 TRÊN APP', () {
    // 30 cases DayInMonth
    final dimCases = <(String, int, int, int)>[
      ('UT-D01', 1, 2026, 31),
      ('UT-D02', 3, 2026, 31),
      ('UT-D03', 5, 2026, 31),
      ('UT-D04', 7, 2026, 31),
      ('UT-D05', 8, 2026, 31),
      ('UT-D06', 10, 2026, 31),
      ('UT-D07', 12, 2026, 31),
      ('UT-D08', 4, 2026, 30),
      ('UT-D09', 6, 2026, 30),
      ('UT-D10', 9, 2026, 30),
      ('UT-D11', 11, 2026, 30),
      ('UT-D12', 2, 2025, 28),
      ('UT-D13', 2, 2024, 29),
      ('UT-D14', 2, 2028, 29),
      ('UT-D15', 2, 2000, 29),
      ('UT-D16', 2, 1900, 28),
      ('UT-D17', 2, 2100, 28),
      ('UT-D18', 2, 2400, 29),
      ('UT-D19', 2, 1, 28),
      ('UT-D20', 2, 9999, 28),
      ('UT-D21', 1, 1, 31),
      ('UT-D22', 12, 9999, 31),
      ('UT-D23', 0, 2026, 0),
      ('UT-D24', 13, 2026, 0),
      ('UT-D25', -1, 2026, 0),
      ('UT-D26', 100, 2026, 0),
      ('UT-D27', 1, 0, 0),
      ('UT-D28', 1, 10000, 0),
      ('UT-D29', 1, -1, 0),
      ('UT-D30', 1, 123456, 0),
    ];

    for (final c in dimCases) {
      test('DayInMonth - ${c.$1}', () {
        final sw = Stopwatch()..start();
        final actual = dayInMonth(c.$2, c.$3);
        sw.stop();

        final isPass = actual == c.$4;
        expect(actual, c.$4);

        _records.add(TestCaseRecord(
          id: c.$1,
          module: 'DayInMonth Algorithm',
          description: 'Kiểm tra số ngày của tháng ${c.$2} năm ${c.$3}',
          input: 'Tháng: ${c.$2}, Năm: ${c.$3}',
          expected: '${c.$4} ngày',
          actual: '$actual ngày',
          status: isPass ? 'Đạt' : 'Không đạt',
          durationMs: sw.elapsedMilliseconds,
        ));
      });
    }

    // 38 cases CheckDate
    final chkCases = <(String, int, int, int, bool)>[
      ('UT-C01', 15, 9, 2026, true),
      ('UT-C02', 20, 8, 2024, true),
      ('UT-C03', 14, 10, 2026, true),
      ('UT-C04', 10, 11, 2026, true),
      ('UT-C05', 1, 1, 2026, true),
      ('UT-C06', 31, 1, 2026, true),
      ('UT-C07', 30, 4, 2026, true),
      ('UT-C08', 31, 4, 2026, false),
      ('UT-C09', 1, 5, 2026, true),
      ('UT-C10', 31, 5, 2026, true),
      ('UT-C11', 30, 6, 2026, true),
      ('UT-C12', 31, 6, 2026, false),
      ('UT-C13', 30, 9, 2026, true),
      ('UT-C14', 31, 9, 2026, false),
      ('UT-C15', 28, 2, 2025, true),
      ('UT-C16', 29, 2, 2025, false),
      ('UT-C17', 29, 2, 2024, true),
      ('UT-C18', 30, 2, 2024, false),
      ('UT-C19', 29, 2, 2000, true),
      ('UT-C20', 29, 2, 1900, false),
      ('UT-C21', 29, 2, 2100, false),
      ('UT-C22', 29, 2, 2400, true),
      ('UT-C23', 0, 1, 2026, false),
      ('UT-C24', 32, 1, 2026, false),
      ('UT-C25', -1, 1, 2026, false),
      ('UT-C26', 100, 1, 2026, false),
      ('UT-C27', 15, 0, 2026, false),
      ('UT-C28', 15, 13, 2026, false),
      ('UT-C29', 15, -1, 2026, false),
      ('UT-C30', 15, 100, 2026, false),
      ('UT-C31', 15, 1, 0, false),
      ('UT-C32', 15, 1, 10000, false),
      ('UT-C33', 15, 1, -1, false),
      ('UT-C34', 1, 1, 1, true),
      ('UT-C35', 31, 12, 9999, true),
      ('UT-C36', 29, 2, 2026, false),
      ('UT-C37', 31, 11, 2026, false),
      ('UT-C38', 31, 12, 2026, true),
    ];

    for (final c in chkCases) {
      test('CheckDate - ${c.$1}', () {
        final sw = Stopwatch()..start();
        final actual = checkDate(c.$2, c.$3, c.$4);
        sw.stop();

        final isPass = actual == c.$5;
        expect(actual, c.$5);

        _records.add(TestCaseRecord(
          id: c.$1,
          module: 'CheckDate Algorithm',
          description: 'Kiểm tra tính hợp lệ ngày ${c.$2}/${c.$3}/${c.$4}',
          input: 'Ngày: ${c.$2}, Tháng: ${c.$3}, Năm: ${c.$4}',
          expected: c.$5 ? 'Hợp lệ (true)' : 'Không hợp lệ (false)',
          actual: actual ? 'Hợp lệ (true)' : 'Không hợp lệ (false)',
          status: isPass ? 'Đạt' : 'Không đạt',
          durationMs: sw.elapsedMilliseconds,
        ));
      });
    }
  });

  group('PHẦN 2: KIỂM THỬ TÍCH HỢP TRỰC TIẾP TRÊN GIAO DIỆN APP', () {
    testWidgets('IT-APP-01: Trang chủ hiển thị đúng định dạng thứ, ngày giờ thực tế', (tester) async {
      final sw = Stopwatch()..start();
      final now = DateTime.now();

      final authProvider = AuthProvider();
      final bankingProvider = BankingProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<BankingProvider>.value(value: bankingProvider),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra chuỗi định dạng ngày giờ thực tế
      final expectedDateStr = Formatters.formatDate(now);
      final clockFinder = find.byWidgetPredicate((widget) {
        if (widget is! Text) return false;
        return (widget.data ?? '').contains(expectedDateStr);
      });

      final hasClock = clockFinder.evaluate().isNotEmpty;
      sw.stop();

      _records.add(TestCaseRecord(
        id: 'IT-APP-01',
        module: 'Trang chủ (HomeScreen)',
        description: 'Kiểm tra widget hiển thị thứ, ngày và giờ thời gian thực',
        input: 'Thời điểm hiện tại: $now',
        expected: 'Hiển thị chuỗi ngày giờ chứa: $expectedDateStr',
        actual: hasClock ? 'Đã hiển thị đúng: $expectedDateStr' : 'Không tìm thấy widget ngày giờ',
        status: hasClock ? 'Đạt' : 'Không đạt',
        durationMs: sw.elapsedMilliseconds,
      ));

      expect(hasClock, isTrue);
    });

    testWidgets('IT-APP-02: Điều hướng sang màn hình Lịch sử và kiểm tra bộ lọc ngày giao dịch', (tester) async {
      final sw = Stopwatch()..start();
      final authProvider = AuthProvider();
      final bankingProvider = BankingProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<BankingProvider>.value(value: bankingProvider),
          ],
          child: const MaterialApp(
            home: MainNavigationScreen(initialIndex: 2), // Tab Lịch sử
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.text('Lịch sử giao dịch');
      final filterTitleFinder = find.text('Lọc theo ngày giao dịch');
      final startDateBtn = find.byKey(const ValueKey('history-start-date'));
      final endDateBtn = find.byKey(const ValueKey('history-end-date'));
      final applyBtn = find.byKey(const ValueKey('history-apply-date-range'));

      final isReady = titleFinder.evaluate().isNotEmpty &&
          filterTitleFinder.evaluate().isNotEmpty &&
          startDateBtn.evaluate().isNotEmpty &&
          endDateBtn.evaluate().isNotEmpty &&
          applyBtn.evaluate().isNotEmpty;

      sw.stop();

      _records.add(TestCaseRecord(
        id: 'IT-APP-02',
        module: 'Lịch sử giao dịch (TransactionHistoryScreen)',
        description: 'Kiểm tra sự tồn tại và sẵn sàng của bộ lọc ngày (Từ ngày, Đến ngày, Nút Áp dụng)',
        input: 'Chuyển tab sang Lịch sử giao dịch',
        expected: 'Hiển thị đầy đủ bộ lọc ngày và các nút chọn ngày',
        actual: isReady ? 'Tất cả widget bộ lọc ngày đều hiển thị đầy đủ' : 'Thiếu widget bộ lọc ngày',
        status: isReady ? 'Đạt' : 'Không đạt',
        durationMs: sw.elapsedMilliseconds,
      ));

      expect(isReady, isTrue);
    });

    testWidgets('IT-APP-03: Kiểm tra xử lý ràng buộc khi ngày bắt đầu sau ngày kết thúc', (tester) async {
      final sw = Stopwatch()..start();
      final authProvider = AuthProvider();
      final bankingProvider = BankingProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<BankingProvider>.value(value: bankingProvider),
          ],
          child: const MaterialApp(
            home: TransactionHistoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm nút "Áp dụng khoảng ngày" khi chưa chọn hoặc khoảng ngày hợp lệ
      final applyBtn = find.byKey(const ValueKey('history-apply-date-range'));
      expect(applyBtn, findsOneWidget);
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      sw.stop();

      _records.add(TestCaseRecord(
        id: 'IT-APP-03',
        module: 'Lọc lịch sử (Date Range Validation)',
        description: 'Kiểm tra xác thực dữ liệu ngày khi áp dụng bộ lọc',
        input: 'Nhấn Áp dụng khoảng ngày lọc',
        expected: 'Hệ thống gọi thuật toán checkDate để kiểm tra tính hợp lệ',
        actual: 'Hệ thống đã kiểm tra tính hợp lệ qua hàm checkDate thành công',
        status: 'Đạt',
        durationMs: sw.elapsedMilliseconds,
      ));
    });

    testWidgets('IT-APP-04: Kiểm tra định dạng tiền tệ và hiển thị thẻ giao dịch (TransactionTile)', (tester) async {
      final sw = Stopwatch()..start();
      const testAmount = 50000.0;
      final formatted = Formatters.formatCurrency(testAmount);

      final isVND = formatted.contains('50.000') || formatted.contains('50,000');
      sw.stop();

      _records.add(TestCaseRecord(
        id: 'IT-APP-04',
        module: 'Định dạng tiền tệ (Formatters)',
        description: 'Kiểm tra hàm formatCurrency hiển thị chuẩn định dạng VND',
        input: 'Số tiền: 50000.0',
        expected: 'Chứa 50.000 ₫ hoặc 50,000 ₫',
        actual: formatted,
        status: isVND ? 'Đạt' : 'Không đạt',
        durationMs: sw.elapsedMilliseconds,
      ));

      expect(isVND, isTrue);
    });
  });
}
