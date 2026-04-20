import 'dart:convert';
import 'dart:typed_data';

class EncryptedMessage {
  final Uint8List encryptedContent;
  final Uint8List encryptedAesKey;
  final String? signature;
  final String hmac;
  final MessageMetadata metadata;

  EncryptedMessage({
    required this.encryptedContent,
    required this.encryptedAesKey,
    this.signature,
    required this.hmac,
    required this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'encryptedContent': base64Encode(encryptedContent),
      'encryptedAesKey': base64Encode(encryptedAesKey),
      'signature': signature,
      'hmac': hmac,
      'metadata': metadata.toJson(),
    };
  }

  factory EncryptedMessage.fromJson(Map<String, dynamic> json) {
    return EncryptedMessage(
      encryptedContent: base64Decode(json['encryptedContent']),
      encryptedAesKey: base64Decode(json['encryptedAesKey']),
      signature: json['signature'],
      hmac: json['hmac'],
      metadata: MessageMetadata.fromJson(json['metadata']),
    );
  }

  String encode() {
    return base64Encode(const Utf8Codec().encode(jsonEncode(toJson())));
  }

  static EncryptedMessage decode(String encoded) {
    final decoded = const Utf8Codec().decode(base64Decode(encoded));
    final json = jsonDecode(decoded);
    return EncryptedMessage.fromJson(json);
  }
}

class MessageMetadata {
  final String messageId;
  final MessageType type;
  final String? fileName;
  final String? fileType;
  final int? fileSize;
  final DateTime timestamp;

  MessageMetadata({
    required this.messageId,
    required this.type,
    this.fileName,
    this.fileType,
    this.fileSize,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'type': type.name,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory MessageMetadata.fromJson(Map<String, dynamic> json) {
    return MessageMetadata(
      messageId: json['messageId'],
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      fileName: json['fileName'],
      fileType: json['fileType'],
      fileSize: json['fileSize'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

enum MessageType { text, image, file }
