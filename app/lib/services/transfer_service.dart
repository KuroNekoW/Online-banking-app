import 'dart:math';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/transfer_model.dart';

class TransferService {
  /// Generate a cryptographically secure UUID v4 string
  static String generateUuidV4() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // Version 4
    values[8] = (values[8] & 0x3f) | 0x80; // Variant 10
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Step 1: Create a draft transfer with idempotency key
  static Future<TransferModel> createTransfer({
    required String sourceAccountId,
    required String destinationAccountNumber,
    String? destinationBankCode,
    required double amount,
    String? description,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? generateUuidV4();
    final response = await ApiClient.post(
      ApiConstants.transfers,
      body: {
        'source_account_id': sourceAccountId,
        'destination_account_number': destinationAccountNumber,
        'destination_bank_code': destinationBankCode,
        'amount': amount,
        'description': description,
        'idempotency_key': key,
      },
    );
    return TransferModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Step 2: Confirm transfer to trigger OTP dispatch (Mailpit)
  static Future<Map<String, dynamic>> confirmTransfer(String transferId) async {
    final response = await ApiClient.post(ApiConstants.transferConfirm(transferId));
    final transferJson = response['transfer'];
    return {
      'transfer': TransferModel.fromJson(Map<String, dynamic>.from(transferJson)),
      'challenge_id': response['challenge_id'] as String?,
      'expires_at': response['expires_at'] != null ? DateTime.tryParse(response['expires_at']) : null,
      'message': response['message'] as String?,
    };
  }

  /// Step 3: Authenticate transfer using 6-digit OTP
  static Future<TransferModel> authenticateTransfer({
    required String transferId,
    required String code,
  }) async {
    final response = await ApiClient.post(
      ApiConstants.transferAuthenticate(transferId),
      body: {'code': code},
    );
    return TransferModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Get transfer details by ID
  static Future<TransferModel> getTransfer(String transferId) async {
    final response = await ApiClient.get(ApiConstants.transferDetail(transferId));
    return TransferModel.fromJson(Map<String, dynamic>.from(response));
  }
}
