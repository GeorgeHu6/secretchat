import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../utils/path_utils.dart';
import '../crypto/models/encrypted_message.dart';
import '../crypto/data_encryption.dart';

class MessageStorageService {
  Future<void> saveMessage(
    String contactId,
    EncryptedMessage message,
    Uint8List encryptionKey,
  ) async {
    final messagesPath = await _getMessagesPath(contactId);
    final fileName = '${message.metadata.messageId}.enc';
    final file = File(p.join(messagesPath, fileName));

    final encoded = message.encode();
    final encrypted = DataEncryption.encryptString(encoded, encryptionKey);
    await file.writeAsString(encrypted);
  }

  Future<List<EncryptedMessage>> loadMessages(
    String contactId,
    Uint8List encryptionKey,
  ) async {
    final messagesPath = await _getMessagesPath(contactId);
    final dir = Directory(messagesPath);

    if (!await dir.exists()) return [];

    final messages = <EncryptedMessage>[];
    final files = dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.enc'),
    );

    for (final file in files) {
      try {
        final encrypted = await file.readAsString();
        final decrypted = DataEncryption.decryptString(encrypted, encryptionKey);
        final message = EncryptedMessage.decode(decrypted);
        messages.add(message);
      } catch (e) {
        continue;
      }
    }

    messages.sort(
      (a, b) => a.metadata.timestamp.compareTo(b.metadata.timestamp),
    );
    return messages;
  }

  Future<void> deleteMessages(String contactId) async {
    final messagesPath = await _getMessagesPath(contactId);
    final dir = Directory(messagesPath);

    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<int> getMessageCount(String contactId) async {
    final messagesPath = await _getMessagesPath(contactId);
    final dir = Directory(messagesPath);

    if (!await dir.exists()) return 0;

    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.enc'))
        .length;
  }

  Future<String> _getMessagesPath(String contactId) async {
    final basePath = await PathUtils.getAppBasePath();
    final messagesPath = p.join(basePath, 'messages', contactId);

    final dir = Directory(messagesPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return messagesPath;
  }
}
