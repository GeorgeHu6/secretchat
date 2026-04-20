import 'contact.dart';

class Conversation {
  final String id;
  final String contactId;
  final String? lastMessagePreview;
  final int unreadCount;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.contactId,
    this.lastMessagePreview,
    this.unreadCount = 0,
    required this.updatedAt,
  });

  Conversation copyWith({
    String? id,
    String? contactId,
    String? lastMessagePreview,
    int? unreadCount,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
