import 'package:secretchat/core/crypto/models/encrypted_message.dart';

class Message {
  final String id;
  final String conversationId;
  final EncryptedMessage? encryptedMessage;
  final String? decryptedContent;
  final bool isSent;
  final MessageStatus status;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    this.encryptedMessage,
    this.decryptedContent,
    required this.isSent,
    required this.status,
    required this.createdAt,
  });

  MessageType get type {
    return encryptedMessage?.metadata.type ?? MessageType.text;
  }

  String? get fileName => encryptedMessage?.metadata.fileName;

  int? get fileSize => encryptedMessage?.metadata.fileSize;
}

enum MessageStatus { encrypted, decrypted, verified, error }
