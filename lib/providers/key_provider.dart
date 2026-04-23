import 'package:flutter/material.dart';
import '../core/crypto/key_manager.dart';
import '../core/storage/file_storage.dart';
import '../core/crypto/models/key_pair.dart';

class KeyProvider extends ChangeNotifier {
  StorageService? _storageService;
  final KeyManager _keyManager = KeyManager();
  final Map<String, KeyPair> _keyPairs = {};
  KeyPair? _defaultKeyPair;

  void setStorageService(StorageService storageService) {
    _storageService = storageService;
  }

  List<KeyPair> get keyPairs => _keyPairs.values.toList();
  KeyPair? get defaultKeyPair => _defaultKeyPair;

  Future<void> loadKeyPairs() async {
    if (_storageService == null) return;

    final keyIds = await _storageService!.listKeyPairs();
    _keyPairs.clear();

    for (final id in keyIds) {
      final pem = await _storageService!.loadKeyPair(id);
      final name = await _storageService!.loadKeyName(id);
      if (pem != null) {
        try {
          final parsedKeyPair = _keyManager.parseRsaPrivateKeyPem(pem);
          final keyPair = KeyPair(
            id: id,
            algorithm: parsedKeyPair.algorithm,
            keySize: parsedKeyPair.keySize,
            publicKeyPem: parsedKeyPair.publicKeyPem,
            privateKeyPem: pem,
            createdAt: parsedKeyPair.createdAt,
            name: name,
          );
          _keyPairs[id] = keyPair;
        } catch (e) {
        }
      }
    }

    if (_keyPairs.isNotEmpty && _defaultKeyPair == null) {
      _defaultKeyPair = _keyPairs.values.first;
    }
    notifyListeners();
  }

  Future<KeyPair> generateKeyPair({int keySize = 2048}) async {
    if (_storageService == null) {
      throw Exception('Storage not initialized');
    }

    final keyPair = await _keyManager.generateRsaKeyPair(keySize: keySize);
    await _storageService!.saveKeyPair(keyPair.id, keyPair.privateKeyPem!);
    _keyPairs[keyPair.id] = keyPair;
    _defaultKeyPair = keyPair;
    notifyListeners();
    return keyPair;
  }

  Future<void> importKeyPair(String pem) async {
    if (_storageService == null) {
      throw Exception('Storage not initialized');
    }

    final keyPair = _keyManager.parseRsaPrivateKeyPem(pem);
    final updatedKeyPair = KeyPair(
      id: keyPair.id,
      algorithm: keyPair.algorithm,
      keySize: keyPair.keySize,
      publicKeyPem: keyPair.publicKeyPem,
      privateKeyPem: pem,
      createdAt: keyPair.createdAt,
    );
    await _storageService!.saveKeyPair(keyPair.id, pem);
    _keyPairs[keyPair.id] = updatedKeyPair;
    notifyListeners();
  }

  Future<void> deleteKeyPair(String keyId) async {
    if (_storageService == null) return;

    _keyPairs.remove(keyId);
    await _storageService!.deleteKeyPair(keyId);
    await _storageService!.deleteKeyName(keyId);
    if (_defaultKeyPair?.id == keyId) {
      _defaultKeyPair = _keyPairs.isNotEmpty ? _keyPairs.values.first : null;
    }
    notifyListeners();
  }

  Future<void> renameKeyPair(String keyId, String newName) async {
    if (_storageService == null) return;

    final keyPair = _keyPairs[keyId];
    if (keyPair == null) return;

    await _storageService!.saveKeyName(keyId, newName);

    final updatedKeyPair = keyPair.copyWith(name: newName);
    _keyPairs[keyId] = updatedKeyPair;

    if (_defaultKeyPair?.id == keyId) {
      _defaultKeyPair = updatedKeyPair;
    }

    notifyListeners();
  }

  void setDefaultKeyPair(String keyId) {
    _defaultKeyPair = _keyPairs[keyId];
    notifyListeners();
  }

  KeyPair? getKeyPair(String keyId) {
    return _keyPairs[keyId];
  }

  void clearState() {
    _keyPairs.clear();
    _defaultKeyPair = null;
    notifyListeners();
  }
}
