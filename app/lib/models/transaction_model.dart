class TransactionEntryModel {
  final String id;
  final String accountId;
  final double amount; // negative for debit, positive for credit

  TransactionEntryModel({
    required this.id,
    required this.accountId,
    required this.amount,
  });

  factory TransactionEntryModel.fromJson(Map<String, dynamic> json) {
    return TransactionEntryModel(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      amount: (json['amount'] != null) ? double.tryParse(json['amount'].toString()) ?? 0.0 : 0.0,
    );
  }
}

class TransactionModel {
  final String id;
  final String reference;
  final String status;
  final String? description;
  final DateTime createdAt;
  final DateTime? postedAt;
  final List<TransactionEntryModel> entries;

  TransactionModel({
    required this.id,
    required this.reference,
    required this.status,
    this.description,
    required this.createdAt,
    this.postedAt,
    this.entries = const [],
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      reference: json['reference'] as String,
      status: json['status'] as String? ?? 'posted',
      description: json['description'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      postedAt: json['posted_at'] != null ? DateTime.tryParse(json['posted_at']) : null,
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) => TransactionEntryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Get the net amount for a given account. If null, returns the first non-zero entry.
  double getAmountForAccount(String? accountId) {
    if (accountId != null) {
      for (final entry in entries) {
        if (entry.accountId == accountId) {
          return entry.amount;
        }
      }
    }
    if (entries.isNotEmpty) {
      return entries.first.amount;
    }
    return 0.0;
  }
}
