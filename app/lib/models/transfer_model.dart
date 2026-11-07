class TransferModel {
  final String id;
  final String reference;
  final String type; // 'internal' or 'interbank'
  final String status; // 'draft', 'pending_authentication', 'processing', 'pending_external', 'completed', 'failed'
  final String sourceAccountId;
  final String? destinationAccountId;
  final double amount;
  final double fee;
  final String currency;
  final String? description;
  final DateTime createdAt;
  final DateTime? completedAt;

  TransferModel({
    required this.id,
    required this.reference,
    required this.type,
    required this.status,
    required this.sourceAccountId,
    this.destinationAccountId,
    required this.amount,
    required this.fee,
    required this.currency,
    this.description,
    required this.createdAt,
    this.completedAt,
  });

  factory TransferModel.fromJson(Map<String, dynamic> json) {
    return TransferModel(
      id: json['id'] as String,
      reference: json['reference'] as String,
      type: json['type'] as String? ?? 'internal',
      status: json['status'] as String? ?? 'draft',
      sourceAccountId: json['source_account_id'] as String,
      destinationAccountId: json['destination_account_id'] as String?,
      amount: (json['amount'] != null) ? double.tryParse(json['amount'].toString()) ?? 0.0 : 0.0,
      fee: (json['fee'] != null) ? double.tryParse(json['fee'].toString()) ?? 0.0 : 0.0,
      currency: json['currency'] as String? ?? 'VND',
      description: json['description'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at']) : null,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isPendingExternal => status == 'pending_external';
  bool get isFailed => status == 'failed';
  bool get isInternal => type == 'internal';
}
