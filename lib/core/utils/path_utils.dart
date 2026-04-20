import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'constants.dart';

class PathUtils {
  static String? _basePath;

  static Future<String> getAppBasePath() async {
    if (_basePath != null) {
      return _basePath!;
    }

    final directory = await getApplicationDocumentsDirectory();
    _basePath = '${directory.path}/${Constants.appDataDir}';

    final baseDir = Directory(_basePath!);
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    return _basePath!;
  }

  static Future<String> getKeysPath() async {
    final basePath = await getAppBasePath();
    final keysPath = '$basePath/${Constants.keysDir}';
    final dir = Directory(keysPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return keysPath;
  }

  static Future<String> getContactsPath() async {
    final basePath = await getAppBasePath();
    final contactsPath =
        '$basePath/${Constants.keysDir}/${Constants.contactsDir}';
    final dir = Directory(contactsPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return contactsPath;
  }

  static Future<String> getKeyFilePath(String keyId) async {
    final keysPath = await getKeysPath();
    return '$keysPath/$keyId.pem';
  }

  static Future<String> getContactPubKeyPath(String contactId) async {
    final contactsPath = await getContactsPath();
    return '$contactsPath/${contactId}_pub.pem';
  }

  static Future<String> getTempDir() async {
    final tempDir = await getTemporaryDirectory();
    final scTempDir = '${tempDir.path}/${Constants.appDataDir}';
    final dir = Directory(scTempDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return scTempDir;
  }
}
