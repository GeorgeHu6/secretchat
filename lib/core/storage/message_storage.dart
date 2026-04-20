import 'dart:io';
import '../utils/path_utils.dart';
import '../crypto/models/encrypted_message.dart';

class MessageStorageService {
  Future<void> saveMessage(String contactId, EncryptedMessage message) async {
    final messagesPath = await _getMessagesPath(contactId);
    final fileName = '${message.metadata.messageId}.enc';
    final file = File('$messagesPath/$fileName');

    final encoded = message.encode();
    await file.writeAsString(encoded);
  }

  Future<List<EncryptedMessage>> loadMessages(String contactId) async {
    final messagesPath = await _getMessagesPath(contactId);
    final dir = Directory(messagesPath);

    if (!await dir.exists()) return [];

    final messages = <EncryptedMessage>[];
    final files = dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.enc'),
    );

    for (final file in files) {
      try {
        final encoded = await file.readAsString();
        final message = EncryptedMessage.decode(encoded);
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
    final messagesPath = '$basePath/messages/$contactId';

    final dir = Directory(messagesPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return messagesPath;
  }
}
