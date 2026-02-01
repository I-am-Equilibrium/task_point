class NotificationModel {
  final String id;
  final String listId;
  final String taskId;
  final String senderId;
  final String receiverId;
  final String senderAvatarUrl;
  final String text;
  final bool isRead;
  final String type;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.listId,
    required this.taskId,
    required this.senderId,
    required this.receiverId,
    required this.senderAvatarUrl,
    required this.text,
    required this.isRead,
    required this.type,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      listId: map['list_id'] ?? '',
      taskId: map['task_id'] ?? '',
      senderId: map['sender_id'] ?? '',
      receiverId: map['receiver_id'] ?? '',
      senderAvatarUrl: map['sender_avatar_url'] ?? '',
      text: map['text'] ?? '',
      isRead: map['is_read'] ?? false,
      type: map['type'] ?? '',
      createdAt: DateTime.parse(
        map['\$createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
