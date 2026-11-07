import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/account_model.dart';
import '../models/beneficiary_model.dart';
import '../models/notification_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';

class BankingService {
  /// Fetch user profile
  static Future<UserModel> getProfile() async {
    final response = await ApiClient.get(ApiConstants.profile);
    return UserModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Update user profile
  static Future<UserModel> updateProfile(String fullName) async {
    final response = await ApiClient.patch(
      ApiConstants.profile,
      body: {'full_name': fullName},
    );
    return UserModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Get list of bank accounts owned by user
  static Future<List<AccountModel>> getAccounts() async {
    final response = await ApiClient.get(ApiConstants.accounts);
    final list = response as List<dynamic>;
    return list.map((e) => AccountModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Get live balance for a specific account
  static Future<double> getAccountBalance(String accountId) async {
    final response = await ApiClient.get(ApiConstants.accountBalance(accountId));
    final balanceVal = response['balance'];
    return double.tryParse(balanceVal.toString()) ?? 0.0;
  }

  /// Get list of saved beneficiaries
  static Future<List<BeneficiaryModel>> getBeneficiaries() async {
    final response = await ApiClient.get(ApiConstants.beneficiaries);
    final list = response as List<dynamic>;
    return list.map((e) => BeneficiaryModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Add a new beneficiary
  static Future<BeneficiaryModel> createBeneficiary({
    required String nickname,
    required String accountNumber,
    required String accountName,
    String? bankCode,
  }) async {
    final response = await ApiClient.post(
      ApiConstants.beneficiaries,
      body: {
        'nickname': nickname,
        'account_number': accountNumber,
        'account_name': accountName,
        'bank_code': bankCode,
      },
    );
    return BeneficiaryModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Delete a beneficiary
  static Future<void> deleteBeneficiary(String beneficiaryId) async {
    await ApiClient.delete(ApiConstants.beneficiaryDetail(beneficiaryId));
  }

  /// Get notifications
  static Future<Map<String, dynamic>> getNotifications({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    final response = await ApiClient.get(
      ApiConstants.notifications,
      queryParams: {
        'unread_only': unreadOnly.toString(),
        'limit': limit.toString(),
      },
    );
    final unreadCount = response['unread_count'] as int? ?? 0;
    final itemsList = response['items'] as List<dynamic>? ?? [];
    final items = itemsList
        .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return {
      'unread_count': unreadCount,
      'items': items,
    };
  }

  /// Mark notification as read
  static Future<void> markNotificationRead(String notificationId) async {
    await ApiClient.post(ApiConstants.markNotificationRead(notificationId));
  }

  /// Get transaction history with pagination
  static Future<Map<String, dynamic>> getTransactions({
    String? accountId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (accountId != null && accountId.isNotEmpty) {
      queryParams['account_id'] = accountId;
    }

    final response = await ApiClient.get(
      ApiConstants.transactions,
      queryParams: queryParams,
    );

    final total = response['total'] as int? ?? 0;
    final itemsList = response['items'] as List<dynamic>? ?? [];
    final items = itemsList
        .map((e) => TransactionModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return {
      'page': page,
      'page_size': pageSize,
      'total': total,
      'items': items,
    };
  }

  /// Get single transaction detail
  static Future<TransactionModel> getTransactionDetail(String transactionId) async {
    final response = await ApiClient.get(ApiConstants.transactionDetail(transactionId));
    return TransactionModel.fromJson(Map<String, dynamic>.from(response));
  }
}
