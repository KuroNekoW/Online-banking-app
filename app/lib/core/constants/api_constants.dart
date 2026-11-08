import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class ApiConstants {
  // Default base URLs depending on environment:
  // Android emulator uses 10.0.2.2 to reach host machine's localhost:8000
  // Windows / Web / iOS simulator can connect directly to 127.0.0.1:8000
  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  // Auth endpoints
  static const String register = '/auth/register';
  static const String registerVerify = '/auth/register/verify';
  static String resendOtp(String challengeId) => '/auth/otp/$challengeId/resend';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String passwordReset = '/auth/password-reset';
  static const String passwordResetConfirm = '/auth/password-reset/confirm';
  static const String changePassword = '/auth/change-password';
  static const String health = '/health';

  // Customer & Banking endpoints
  static const String profile = '/profile';
  static const String accounts = '/accounts';
  static String accountDetail(String id) => '/accounts/$id';
  static String accountBalance(String id) => '/accounts/$id/balance';
  static const String beneficiaries = '/beneficiaries';
  static String beneficiaryDetail(String id) => '/beneficiaries/$id';
  static const String notifications = '/notifications';
  static String markNotificationRead(String id) => '/notifications/$id/read';
  static const String transactions = '/transactions';
  static String transactionDetail(String id) => '/transactions/$id';

  // Transfer endpoints
  static const String transfers = '/transfers';
  static String transferDetail(String id) => '/transfers/$id';
  static String transferConfirm(String id) => '/transfers/$id/confirm';
  static String transferAuthenticate(String id) => '/transfers/$id/authenticate';
}
