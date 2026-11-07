import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');

  /// Format money to Vietnamese Dong, e.g. "1,500,000 ₫"
  static String formatCurrency(num? amount, {String currency = 'VND'}) {
    if (amount == null) return '0 ₫';
    if (currency == 'VND') {
      return _currencyFormat.format(amount);
    }
    return '${NumberFormat('#,##0.00').format(amount)} $currency';
  }

  /// Format DateTime to "dd/MM/yyyy HH:mm"
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _dateTimeFormat.format(dateTime.toLocal());
  }

  /// Format DateTime to "dd/MM/yyyy"
  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _dateFormat.format(dateTime.toLocal());
  }

  /// Format DateTime to "HH:mm"
  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _timeFormat.format(dateTime.toLocal());
  }

  /// Mask account number, e.g. "100123456789" -> "1001 •••• 6789"
  static String maskAccountNumber(String? accountNumber) {
    if (accountNumber == null || accountNumber.isEmpty) return '••••';
    if (accountNumber.length <= 6) return accountNumber;
    final prefix = accountNumber.substring(0, 4);
    final suffix = accountNumber.substring(accountNumber.length - 4);
    return '$prefix •••• $suffix';
  }
}
