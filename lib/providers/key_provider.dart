import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pointycastle/export.dart';
import '../core/crypto/key_manager.dart';
import '../core/storage/file_storage.dart';
import '../core/crypto/models/key_pair.dart';
import '../core/utils/constants.dart';

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
          KeyPair keyPair;
          if (_keyManager.isEccKey(pem)) {
            keyPair = await _parseEcKeyPair(pem, id, name);
          } else {
            keyPair = _parseRsaKeyPair(pem, id, name);
          }
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

  KeyPair _parseRsaKeyPair(String pem, String id, String? name) {
    final parsedKeyPair = _keyManager.parseRsaPrivateKeyPem(pem);
    return KeyPair(
      id: id,
      algorithm: parsedKeyPair.algorithm,
      keySize: parsedKeyPair.keySize,
      publicKeyPem: parsedKeyPair.publicKeyPem,
      privateKeyPem: pem,
      createdAt: parsedKeyPair.createdAt,
      name: name,
    );
  }

  Future<KeyPair> _parseEcKeyPair(String pem, String id, String? name) async {
    final privateKey = _keyManager.parseEcPrivateKeyPem(pem);
    if (privateKey == null) {
      throw Exception('Failed to parse EC private key');
    }

    final curve = ECCurve_secp256r1();
    final publicKeyPoint = curve.G * privateKey.d!;
    final publicKey = ECPublicKey(publicKeyPoint, curve);

    return KeyPair(
      id: id,
      algorithm: KeyAlgorithm.ecc,
      keySize: 256,
      publicKeyPem: _encodeEcPublicKeyPemFromKey(publicKey),
      privateKeyPem: pem,
      createdAt: DateTime.now(),
      name: name,
    );
  }

  String _encodeEcPublicKeyPemFromKey(ECPublicKey publicKey) {
    final point = publicKey.Q!;
    final encodedPoint = point.getEncoded(false);

    final oidBytes = [
      0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01,
    ];
    final curveOidBytes = [
      0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07,
    ];
    final algorithmId = _encodeDerSequence([...oidBytes, ...curveOidBytes]);

    final bitStringContent = [0x00, ...encodedPoint];
    final bitString = _encodeDerBitString(bitStringContent);

    final spkiContent = [...algorithmId, ...bitString];
    final spkiSequence = _encodeDerSequence(spkiContent);

    final base64Str = base64Encode(spkiSequence);
    return _formatPem(
      base64Str,
      Constants.pemHeaderEcPublicKey,
      Constants.pemFooterEcPublicKey,
    );
  }

  List<int> _encodeDerSequence(List<int> content) {
    final lengthBytes = _encodeDerLength(content.length);
    return [0x30, ...lengthBytes, ...content];
  }

  List<int> _encodeDerBitString(List<int> content) {
    final lengthBytes = _encodeDerLength(content.length);
    return [0x03, ...lengthBytes, ...content];
  }

  List<int> _encodeDerLength(int length) {
    if (length < 128) return [length];
    final bytes = <int>[];
    var remaining = length;
    while (remaining > 0) {
      bytes.insert(0, remaining & 0xFF);
      remaining >>= 8;
    }
    return [0x80 | bytes.length, ...bytes];
  }

  String _formatPem(String base64, String header, String footer) {
    final lines = <String>[];
    for (var i = 0; i < base64.length; i += 64) {
      final end = i + 64;
      lines.add(base64.substring(i, end > base64.length ? base64.length : end));
    }
    return '$header\n${lines.join('\n')}\n$footer';
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

  Future<KeyPair> generateEccKeyPair() async {
    if (_storageService == null) {
      throw Exception('Storage not initialized');
    }

    final keyPair = await _keyManager.generateEccKeyPair();
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
