import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'dart:io';
import '../utils/path_utils.dart';
import '../utils/constants.dart';

class StorageService {
  final Random _random = Random.secure();
  Uint8List? _derivedKey;

  bool get isUnlocked => _derivedKey != null;

  Future<void> initializeStorage(String password) async {
    final salt = _generateSalt();
    final derivedKey = _deriveKeySync(password, salt);

    await _writeSalt(salt);
    await _writePasswordHash(derivedKey);

    _derivedKey = derivedKey;
  }

  Future<bool> verifyPassword(String password) async {
    final salt = await readSalt();
    if (salt == null) return false;

    final testKey = _deriveKeySync(password, salt);
    final storedHash = await readPasswordHash();

    if (storedHash == null) return false;

    return _constantTimeCompare(testKey, storedHash);
  }

  Future<void> unlock(String password) async {
    final valid = await verifyPassword(password);
    if (!valid) throw Exception('Invalid password');

    final salt = await readSalt();
    _derivedKey = _deriveKeySync(password, salt!);
  }

  void lock() {
    _derivedKey = null;
  }

  Uint8List _generateSalt() {
    return Uint8List.fromList(
      List.generate(Constants.saltLength, (_) => _random.nextInt(256)),
    );
  }

  Uint8List _deriveKeySync(String password, Uint8List salt) {
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, Constants.pbkdf2Iterations, 32));
    return pbkdf2.process(passwordBytes);
  }

  Future<void> _writeSalt(Uint8List salt) async {
    final basePath = await PathUtils.getAppBasePath();
    final file = File('$basePath/salt.dat');
    await file.writeAsBytes(salt);
  }

  Future<Uint8List?> readSalt() async {
    final basePath = await PathUtils.getAppBasePath();
    final file = File('$basePath/salt.dat');
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  }

  Future<void> _writePasswordHash(Uint8List hash) async {
    final basePath = await PathUtils.getAppBasePath();
    final file = File('$basePath/hash.dat');
    await file.writeAsBytes(hash);
  }

  Future<Uint8List?> readPasswordHash() async {
    final basePath = await PathUtils.getAppBasePath();
    final file = File('$basePath/hash.dat');
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  }

  bool _constantTimeCompare(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  Future<void> saveKeyPair(String keyId, String pemData) async {
    final filePath = await PathUtils.getKeyFilePath(keyId);
    await File(filePath).writeAsString(pemData);
  }

  Future<String?> loadKeyPair(String keyId) async {
    final filePath = await PathUtils.getKeyFilePath(keyId);
    final file = File(filePath);
    if (!await file.exists()) return null;
    return await file.readAsString();
  }

  Future<void> deleteKeyPair(String keyId) async {
    final filePath = await PathUtils.getKeyFilePath(keyId);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> saveContactPublicKey(
    String contactId,
    String publicKeyPem,
  ) async {
    final filePath = await PathUtils.getContactPubKeyPath(contactId);
    await File(filePath).writeAsString(publicKeyPem);
  }

  Future<String?> loadContactPublicKey(String contactId) async {
    final filePath = await PathUtils.getContactPubKeyPath(contactId);
    final file = File(filePath);
    if (!await file.exists()) return null;
    return await file.readAsString();
  }

  Future<void> deleteContactPublicKey(String contactId) async {
    final filePath = await PathUtils.getContactPubKeyPath(contactId);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<List<String>> listKeyPairs() async {
    final keysPath = await PathUtils.getKeysPath();
    final dir = Directory(keysPath);
    if (!await dir.exists()) return [];

    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.pem'))
        .map((f) => f.path.split('/').last.replaceAll('.pem', ''))
        .toList();
  }

  Future<void> saveKeyName(String keyId, String name) async {
    final metadata = await _loadKeyMetadata();
    metadata[keyId] = name;
    await _saveKeyMetadata(metadata);
  }

  Future<String?> loadKeyName(String keyId) async {
    final metadata = await _loadKeyMetadata();
    return metadata[keyId];
  }

  Future<void> deleteKeyName(String keyId) async {
    final metadata = await _loadKeyMetadata();
    metadata.remove(keyId);
    await _saveKeyMetadata(metadata);
  }

  Future<Map<String, String>> _loadKeyMetadata() async {
    final basePath = await PathUtils.getAppBasePath();
    final file = File('$basePath/key_names.json');

    if (!await file.exists()) return {};

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return json.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      return {};
    }
  }

  Future<void> _saveKeyMetadata(Map<String, String> metadata) async {
    final basePath = await PathUtils.getAppBasePath();
    final file = File('$basePath/key_names.json');
    await file.writeAsString(jsonEncode(metadata));
  }

  Future<List<String>> listContactPublicKeys() async {
    final contactsPath = await PathUtils.getContactsPath();
    final dir = Directory(contactsPath);
    if (!await dir.exists()) return [];

    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('_pub.pem'))
        .map((f) => f.path.split('/').last.replaceAll('_pub.pem', ''))
        .toList();
  }

  Future<void> clearAllData() async {
    final basePath = await PathUtils.getAppBasePath();
    final baseDir = Directory(basePath);

    if (await baseDir.exists()) {
      await baseDir.delete(recursive: true);
    }

    _derivedKey = null;
  }

  Future<bool> hasSetup() async {
    final salt = await readSalt();
    return salt != null;
  }
}
