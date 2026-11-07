import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/storage/storage_service.dart';
import '../models/user_model.dart';

class AuthService {
  /// Register a new account - triggers OTP via Mailpit
  static Future<Map<String, dynamic>> register({
    required String email,
    required String phone,
    required String fullName,
    required String password,
  }) async {
    final response = await ApiClient.post(
      ApiConstants.register,
      body: {
        'email': email,
        'phone': phone,
        'full_name': fullName,
        'password': password,
      },
    );
    return Map<String, dynamic>.from(response);
  }

  /// Verify registration OTP to activate account
  static Future<Map<String, dynamic>> verifyRegistration({
    required String challengeId,
    required String code,
  }) async {
    final response = await ApiClient.post(
      ApiConstants.registerVerify,
      body: {
        'challenge_id': challengeId,
        'code': code,
      },
    );
    return Map<String, dynamic>.from(response);
  }

  /// Resend OTP challenge
  static Future<Map<String, dynamic>> resendOtp(String challengeId) async {
    final response = await ApiClient.post(ApiConstants.resendOtp(challengeId));
    return Map<String, dynamic>.from(response);
  }

  /// Login with email/phone/username and password
  static Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    final response = await ApiClient.post(
      ApiConstants.login,
      body: {
        'identifier': identifier,
        'password': password,
      },
    );

    final accessToken = response['access_token'] as String;
    final refreshToken = response['refresh_token'] as String;

    await StorageService.setAccessToken(accessToken);
    await StorageService.setRefreshToken(refreshToken);

    return await getMe();
  }

  /// Get current authenticated user profile
  static Future<UserModel> getMe() async {
    final response = await ApiClient.get(ApiConstants.me);
    return UserModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Logout current session
  static Future<void> logout() async {
    try {
      await ApiClient.post(ApiConstants.logout);
    } catch (_) {
      // Ignore network errors during logout
    } finally {
      await StorageService.clearTokens();
    }
  }

  /// Request password reset
  static Future<Map<String, dynamic>> requestPasswordReset(String identifier) async {
    final response = await ApiClient.post(
      '${ApiConstants.passwordReset}?identifier=${Uri.encodeComponent(identifier)}',
    );
    return Map<String, dynamic>.from(response);
  }

  /// Confirm password reset with OTP
  static Future<void> confirmPasswordReset({
    required String challengeId,
    required String code,
    required String newPassword,
  }) async {
    await ApiClient.post(
      ApiConstants.passwordResetConfirm,
      body: {
        'challenge_id': challengeId,
        'code': code,
        'new_password': newPassword,
      },
    );
  }

  /// Change password for logged-in user
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await ApiClient.post(
      ApiConstants.changePassword,
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }
}
