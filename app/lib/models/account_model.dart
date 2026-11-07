class AccountModel {
  final String id;
  final String accountNumber;
  final String currency;
  final String status;
  final double balance;
  final DateTime? updatedAt;

  AccountModel({
    required this.id,
    required this.accountNumber,
    required this.currency,
    required this.status,
    required this.balance,
    this.updatedAt,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'] as String,
      accountNumber: json['account_number'] as String,
      currency: json['currency'] as String? ?? 'VND',
      status: json['status'] as String? ?? 'active',
      balance: (json['balance'] != null) ? double.tryParse(json['balance'].toString()) ?? 0.0 : 0.0,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_number': accountNumber,
      'currency': currency,
      'status': status,
      'balance': balance,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isActive => status == 'active';
}
