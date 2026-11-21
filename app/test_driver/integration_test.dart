import 'dart:io';

import 'package:excel/excel.dart';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
      responseDataCallback: _writeExcelReport,
      writeResponseOnFailure: true,
    );

Future<void> _writeExcelReport(Map<String, dynamic>? data) async {
  final rawReport = data?['appDateTimeReport'];
  final report = rawReport is Map
      ? Map<String, dynamic>.from(rawReport)
      : <String, dynamic>{};
  final rawTests = report['tests'];
  final tests = rawTests is List
      ? rawTests
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : <Map<String, dynamic>>[];

  final passed = tests.where((test) => test['status'] == 'Đạt').length;
  final failed = tests.where((test) => test['status'] == 'Không đạt').length;
  final workbook = Excel.createExcel();
  workbook.rename('Sheet1', 'Tổng quan');
  final summary = workbook['Tổng quan'];
  summary.appendRow([TextCellValue('BÁO CÁO KIỂM THỬ NGÀY GIỜ TRÊN APP')]);
  summary.appendRow([
    TextCellValue('Thời điểm chạy'),
    TextCellValue(report['startedAt']?.toString() ?? 'Không có dữ liệu'),
  ]);
  summary.appendRow([
    TextCellValue('Tổng số test'),
    IntCellValue(tests.length),
  ]);
  summary.appendRow([TextCellValue('Đạt'), IntCellValue(passed)]);
  summary.appendRow([TextCellValue('Không đạt'), IntCellValue(failed)]);
  summary.appendRow([
    TextCellValue('Kết luận'),
    TextCellValue(
      tests.isEmpty
          ? 'Không có dữ liệu test'
          : failed == 0
              ? 'Đạt'
              : 'Có test không đạt',
    ),
  ]);

  final details = workbook['Chi tiết'];
  details.appendRow([
    TextCellValue('Mã test'),
    TextCellValue('Nội dung'),
    TextCellValue('Kết quả'),
    TextCellValue('Thời gian (ms)'),
    TextCellValue('Chi tiết lỗi'),
  ]);
  for (final test in tests) {
    details.appendRow([
      TextCellValue(test['id']?.toString() ?? ''),
      TextCellValue(test['description']?.toString() ?? ''),
      TextCellValue(test['status']?.toString() ?? 'Chưa chạy'),
      DoubleCellValue((test['durationMs'] as num?)?.toDouble() ?? 0),
      TextCellValue(test['details']?.toString() ?? ''),
    ]);
  }

  final bytes = workbook.encode();
  if (bytes == null) {
    throw StateError('Không thể tạo nội dung workbook Excel.');
  }

  final reportDirectory = Directory(
    '${Directory.current.path}${Platform.pathSeparator}'
    'integration_test${Platform.pathSeparator}reports',
  );
  await reportDirectory.create(recursive: true);
  final fileName = 'DateTimeIntegrationReport_${_fileTimestamp()}.xlsx';
  final reportFile = File(
    '${reportDirectory.path}${Platform.pathSeparator}$fileName',
  );
  await reportFile.writeAsBytes(bytes, flush: true);
  stdout.writeln('Đã lưu báo cáo Excel: ${reportFile.path}');
}

String _fileTimestamp() {
  final now = DateTime.now();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${now.year}${twoDigits(now.month)}${twoDigits(now.day)}_'
      '${twoDigits(now.hour)}${twoDigits(now.minute)}${twoDigits(now.second)}';
}
