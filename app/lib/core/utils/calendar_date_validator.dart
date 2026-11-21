/// Calendar validation helpers corresponding to the Lab 2 algorithms.
///
/// The supported Gregorian year range is 1 through 9999.
int dayInMonth(int month, int year) {
  if (year < 1 || year > 9999 || month < 1 || month > 12) return 0;

  if (month == 2) {
    final isLeapYear = year % 400 == 0 || (year % 4 == 0 && year % 100 != 0);
    return isLeapYear ? 29 : 28;
  }

  if (month == 4 || month == 6 || month == 9 || month == 11) return 30;
  return 31;
}

/// Returns whether [day], [month], and [year] form a valid Gregorian date.
bool checkDate(int day, int month, int year) {
  final maxDay = dayInMonth(month, year);
  return day >= 1 && day <= maxDay;
}
