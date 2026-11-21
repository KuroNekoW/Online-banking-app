import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/utils/calendar_date_validator.dart';

void main() {
  group('dayInMonth (Lab 2 OB-DIM)', () {
    final cases = <(int, int, int)>[
      (1, 2026, 31),
      (3, 2026, 31),
      (5, 2026, 31),
      (7, 2026, 31),
      (8, 2026, 31),
      (10, 2026, 31),
      (12, 2026, 31),
      (4, 2026, 30),
      (6, 2026, 30),
      (9, 2026, 30),
      (11, 2026, 30),
      (2, 2025, 28),
      (2, 2024, 29),
      (2, 2028, 29),
      (2, 2000, 29),
      (2, 1900, 28),
      (2, 2100, 28),
      (2, 2400, 29),
      (2, 1, 28),
      (2, 9999, 28),
      (1, 1, 31),
      (12, 9999, 31),
      (0, 2026, 0),
      (13, 2026, 0),
      (-1, 2026, 0),
      (100, 2026, 0),
      (1, 0, 0),
      (1, 10000, 0),
      (1, -1, 0),
      (1, 123456, 0),
    ];

    for (var i = 0; i < cases.length; i++) {
      final (month, year, expected) = cases[i];
      test('UT-D${(i + 1).toString().padLeft(2, '0')}', () {
        expect(dayInMonth(month, year), expected);
      });
    }
  });

  group('checkDate (Lab 2 OB-CHK)', () {
    final cases = <(int, int, int, bool)>[
      (15, 9, 2026, true),
      (20, 8, 2024, true),
      (14, 10, 2026, true),
      (10, 11, 2026, true),
      (1, 1, 2026, true),
      (31, 1, 2026, true),
      (30, 4, 2026, true),
      (31, 4, 2026, false),
      (1, 5, 2026, true),
      (31, 5, 2026, true),
      (30, 6, 2026, true),
      (31, 6, 2026, false),
      (30, 9, 2026, true),
      (31, 9, 2026, false),
      (28, 2, 2025, true),
      (29, 2, 2025, false),
      (29, 2, 2024, true),
      (30, 2, 2024, false),
      (29, 2, 2000, true),
      (29, 2, 1900, false),
      (29, 2, 2100, false),
      (29, 2, 2400, true),
      (0, 1, 2026, false),
      (32, 1, 2026, false),
      (-1, 1, 2026, false),
      (100, 1, 2026, false),
      (15, 0, 2026, false),
      (15, 13, 2026, false),
      (15, -1, 2026, false),
      (15, 100, 2026, false),
      (15, 1, 0, false),
      (15, 1, 10000, false),
      (15, 1, -1, false),
      (1, 1, 1, true),
      (31, 12, 9999, true),
      (29, 2, 2026, false),
      (31, 11, 2026, false),
      (31, 12, 2026, true),
    ];

    for (var i = 0; i < cases.length; i++) {
      final (day, month, year, expected) = cases[i];
      test('UT-C${(i + 1).toString().padLeft(2, '0')}', () {
        expect(checkDate(day, month, year), expected);
      });
    }
  });
}
