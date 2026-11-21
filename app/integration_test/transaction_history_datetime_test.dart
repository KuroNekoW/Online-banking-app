import 'package:app/core/storage/storage_service.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/main.dart' as banking_app;
import 'package:app/screens/auth/login_screen.dart';
import 'package:app/screens/home/home_screen.dart';
import 'package:app/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _testEmail = String.fromEnvironment(
  'BANKING_TEST_EMAIL',
  defaultValue: 'alice.demo@banking.local',
);
const _testPassword = String.fromEnvironment(
  'BANKING_TEST_PASSWORD',
  defaultValue: 'DemoCustomer123!',
);
const _testApiBaseUrl = String.fromEnvironment('BANKING_TEST_API_URL');

late IntegrationTestWidgetsFlutterBinding _binding;
final List<Map<String, Object?>> _testResults = [];
late DateTime _runStartedAt;

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    _testResults.clear();
    _runStartedAt = DateTime.now();
    _publishReport();
    await StorageService.init();
    await StorageService.clearTokens();
    if (_testApiBaseUrl.isNotEmpty) {
      await StorageService.setCustomBaseUrl(_testApiBaseUrl);
    } else {
      await StorageService.clearCustomBaseUrl();
    }
  });

  testWidgets(
    'home date/time and transaction history date filter',
    (tester) async {
      await _recordCase(
        'APP-DT-SETUP',
        'Đăng nhập tài khoản demo',
        () async {
          banking_app.main();
          await _waitFor(tester, find.byType(LoginScreen));
          final fields = find.byType(TextFormField);
          expect(fields, findsNWidgets(2));
          await tester.enterText(fields.at(0), _testEmail);
          await tester.enterText(fields.at(1), _testPassword);
          await tester.tap(find.text('Đăng nhập').last);
          await _waitFor(tester, find.byType(HomeScreen));
        },
      );

      final today = DateTime.now();
      await _recordCase(
        'APP-DT-01',
        'Trang chủ hiển thị thứ, ngày và giờ',
        () async {
          final clockText = find.byWidgetPredicate((widget) {
            if (widget is! Text) return false;
            return (widget.data ?? '').contains(Formatters.formatDate(today));
          });
          expect(clockText, findsOneWidget);

          final clockLabel = tester.widget<Text>(clockText).data!;
          final weekday = clockLabel.split(',').first;
          expect(
            weekday,
            isIn([
              'Thứ Hai',
              'Thứ Ba',
              'Thứ Tư',
              'Thứ Năm',
              'Thứ Sáu',
              'Thứ Bảy',
              'Chủ Nhật',
            ]),
          );
          final timeText = clockLabel.substring(clockLabel.length - 5);
          expect(timeText[2], ':');
          expect(
            int.tryParse(timeText.substring(0, 2)),
            inInclusiveRange(0, 23),
          );
          expect(
            int.tryParse(timeText.substring(3, 5)),
            inInclusiveRange(0, 59),
          );
        },
      );

      await _recordCase(
        'APP-DT-02',
        'Lịch sử chấp nhận khoảng lọc một ngày',
        () async {
          final historyTab = find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Lịch sử'),
          );
          await tester.tap(historyTab);
          await _waitFor(tester, find.text('Lọc theo ngày giao dịch'));

          await _chooseDate(tester, 'history-start-date', today);
          await _chooseDate(tester, 'history-end-date', today);
          expect(find.text(_formatDate(today)), findsNWidgets(2));

          final applyButton = find.byKey(
            const ValueKey('history-apply-date-range'),
          );
          await tester.tap(applyButton);
          await _waitForEnabled(tester, applyButton);
          expect(find.byType(SnackBar), findsNothing);
          expect(
            find.text('Không tìm thấy giao dịch nào').evaluate().isNotEmpty ||
                find.byType(TransactionTile).evaluate().isNotEmpty,
            isTrue,
          );
        },
      );

      await _recordCase(
        'APP-DT-03',
        'Lịch sử từ chối khoảng ngày bị đảo ngược',
        () async {
          final tomorrow = today.add(const Duration(days: 1));
          await _chooseDate(tester, 'history-start-date', tomorrow);
          await _chooseDate(tester, 'history-end-date', today);
          await tester.tap(
            find.byKey(const ValueKey('history-apply-date-range')),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('Ngày bắt đầu không được sau ngày kết thúc'),
            findsOneWidget,
          );
        },
      );
    },
  );
}

Future<void> _recordCase(
  String id,
  String description,
  Future<void> Function() action,
) async {
  final stopwatch = Stopwatch()..start();
  try {
    await action();
    stopwatch.stop();
    _testResults.add({
      'id': id,
      'description': description,
      'status': 'Đạt',
      'durationMs': stopwatch.elapsedMilliseconds,
      'details': '',
    });
    _publishReport();
  } catch (error) {
    stopwatch.stop();
    _testResults.add({
      'id': id,
      'description': description,
      'status': 'Không đạt',
      'durationMs': stopwatch.elapsedMilliseconds,
      'details': error.toString(),
    });
    _publishReport();
    rethrow;
  }
}

void _publishReport() {
  _binding.reportData = {
    'appDateTimeReport': {
      'startedAt': _runStartedAt.toIso8601String(),
      'tests': List<Map<String, Object?>>.of(_testResults),
    },
  };
}

Future<void> _chooseDate(
  WidgetTester tester,
  String buttonKey,
  DateTime date,
) async {
  await tester.tap(find.byKey(ValueKey(buttonKey)));
  await tester.pumpAndSettle();

  final dayCell = find.text(date.day.toString());
  expect(dayCell, findsOneWidget);
  await tester.tap(dayCell);
  await tester.tap(find.text('CHỌN'));
  await tester.pumpAndSettle();
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 120; attempt++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsOneWidget);
}

Future<void> _waitForEnabled(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 120; attempt++) {
    final button = tester.widget<TextButton>(finder);
    if (button.onPressed != null) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(tester.widget<TextButton>(finder).onPressed, isNotNull);
}

String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year.toString().padLeft(4, '0')}';
