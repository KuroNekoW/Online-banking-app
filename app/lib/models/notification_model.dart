class NotificationModel {
  final String id;
  final String userId;
  final String? transferId;
  final String type;
  final String title;
  final String body;
  final DateTime? readAt;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    this.transferId,
    required this.type,
    required this.title,
    required this.body,
    this.readAt,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      transferId: json['transfer_id'] as String?,
      type: json['type'] as String? ?? 'account',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  bool get isRead => readAt != null;
}
