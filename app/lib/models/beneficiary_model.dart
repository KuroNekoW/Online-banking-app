class BeneficiaryModel {
  final String id;
  final String ownerId;
  final String nickname;
  final String accountNumber;
  final String accountName;
  final String? bankCode;
  final bool isInternal;
  final DateTime? createdAt;

  BeneficiaryModel({
    required this.id,
    required this.ownerId,
    required this.nickname,
    required this.accountNumber,
    required this.accountName,
    this.bankCode,
    this.isInternal = false,
    this.createdAt,
  });

  factory BeneficiaryModel.fromJson(Map<String, dynamic> json) {
    return BeneficiaryModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      nickname: json['nickname'] as String,
      accountNumber: json['account_number'] as String,
      accountName: json['account_name'] as String,
      bankCode: json['bank_code'] as String?,
      isInternal: json['is_internal'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'account_number': accountNumber,
      'account_name': accountName,
      'bank_code': bankCode,
    };
  }
}
