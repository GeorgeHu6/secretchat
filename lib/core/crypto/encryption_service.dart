import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as pkg;
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'models/encrypted_message.dart';
import 'key_manager.dart';

class EncryptionService {
  final Random _random = Random.secure();
  final KeyManager _keyManager = KeyManager();
  late final SecureRandom _secureRandom;

  EncryptionService() {
    _secureRandom = SecureRandom('Fortuna');
    _secureRandom.seed(
      KeyParameter(
        Uint8List.fromList(List.generate(32, (_) => _random.nextInt(256))),
      ),
    );
  }

  Future<EncryptedMessage> encryptText(
    String text,
    String recipientPublicKeyPem,
    String senderPrivateKeyPem,
  ) async {
    final contentBytes = Uint8List.fromList(utf8.encode(text));
    return _encryptContent(
      contentBytes,
      MessageType.text,
      recipientPublicKeyPem,
      senderPrivateKeyPem,
    );
  }

  Future<EncryptedMessage> encryptForStorage(
    String text,
    String myPublicKeyPem,
    String myPrivateKeyPem,
  ) async {
    final contentBytes = Uint8List.fromList(utf8.encode(text));
    return _encryptContent(
      contentBytes,
      MessageType.text,
      myPublicKeyPem,
      myPrivateKeyPem,
    );
  }

  Future<EncryptedMessage> encryptFile(
    Uint8List fileData,
    String fileName,
    String fileType,
    String recipientPublicKeyPem,
    String senderPrivateKeyPem,
  ) async {
    return _encryptContent(
      fileData,
      fileType.startsWith('image') ? MessageType.image : MessageType.file,
      recipientPublicKeyPem,
      senderPrivateKeyPem,
      fileName: fileName,
      fileSize: fileData.length,
    );
  }

  Future<EncryptedMessage> _encryptContent(
    Uint8List content,
    MessageType type,
    String recipientPublicKeyPem,
    String senderPrivateKeyPem, {
    String? fileName,
    int? fileSize,
  }) async {
    final aesKeyBytes = _generateRandomBytes(32);
    final ivBytes = _generateRandomBytes(12);

    final aesKey = pkg.Key(aesKeyBytes);
    final iv = pkg.IV(ivBytes);

    final encrypter = pkg.Encrypter(pkg.AES(aesKey, mode: pkg.AESMode.gcm));
    final encrypted = encrypter.encryptBytes(content, iv: iv);

    final publicKey = _keyManager.parsePublicKeyPem(recipientPublicKeyPem);
    if (publicKey == null) throw Exception('Invalid recipient public key');

    final rsaEncrypter = pkg.Encrypter(pkg.RSA(publicKey: publicKey));
    final encryptedAesKey = rsaEncrypter.encryptBytes(aesKeyBytes);

    final ivAndEncrypted = Uint8List.fromList([...ivBytes, ...encrypted.bytes]);

    final signature = _signContent(content, senderPrivateKeyPem);
    final hmac = _generateHmac(content, aesKeyBytes);

    return EncryptedMessage(
      encryptedContent: ivAndEncrypted,
      encryptedAesKey: Uint8List.fromList(encryptedAesKey.bytes),
      signature: signature,
      hmac: hmac,
      metadata: MessageMetadata(
        messageId: _generateId(),
        type: type,
        fileName: fileName,
        fileSize: fileSize,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<String> decryptText(
    EncryptedMessage message,
    String recipientPrivateKeyPem,
    String senderPublicKeyPem,
  ) async {
    final bytes = await _decryptContent(
      message,
      recipientPrivateKeyPem,
      senderPublicKeyPem,
    );
    return utf8.decode(bytes);
  }

  Future<Uint8List> decryptFile(
    EncryptedMessage message,
    String recipientPrivateKeyPem,
    String senderPublicKeyPem,
  ) async {
    return _decryptContent(message, recipientPrivateKeyPem, senderPublicKeyPem);
  }

  Future<Uint8List> _decryptContent(
    EncryptedMessage message,
    String recipientPrivateKeyPem,
    String senderPublicKeyPem,
  ) async {
    final privateKey = _keyManager.parsePrivateKeyPem(recipientPrivateKeyPem);
    if (privateKey == null) throw Exception('Invalid private key');

    final rsaDecrypter = pkg.Encrypter(pkg.RSA(privateKey: privateKey));
    final aesKeyBytes = Uint8List.fromList(
      rsaDecrypter.decryptBytes(pkg.Encrypted(message.encryptedAesKey)),
    );

    final ivBytes = message.encryptedContent.sublist(0, 12);
    final encryptedBytes = message.encryptedContent.sublist(12);

    final aesKey = pkg.Key(aesKeyBytes);
    final iv = pkg.IV(ivBytes);
    final encrypter = pkg.Encrypter(pkg.AES(aesKey, mode: pkg.AESMode.gcm));

    final decrypted = Uint8List.fromList(
      encrypter.decryptBytes(pkg.Encrypted(encryptedBytes), iv: iv),
    );

    final senderPublicKey = _keyManager.parsePublicKeyPem(senderPublicKeyPem);
    if (senderPublicKey != null) {
      if (!_verifySignature(decrypted, message.signature, senderPublicKey)) {
        throw Exception('签名验证失败 - 消息可能被篡改或发送方身份不匹配');
      }
    }

    if (!_verifyHmac(decrypted, aesKeyBytes, message.hmac)) {
      throw Exception('HMAC验证失败 - 消息完整性受损');
    }

    return decrypted;
  }

  Uint8List _generateRandomBytes(int length) {
    return Uint8List.fromList(
      List.generate(length, (_) => _random.nextInt(256)),
    );
  }

  String _generateId() {
    return List.generate(
      16,
      (_) => _random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String? _signContent(Uint8List content, String privateKeyPem) {
    try {
      final privateKey = _keyManager.parsePrivateKeyPem(privateKeyPem);
      if (privateKey == null) return null;

      final signer = Signer('SHA-256/RSA');
      signer.init(
        true,
        ParametersWithRandom<PrivateKeyParameter<RSAPrivateKey>>(
          PrivateKeyParameter<RSAPrivateKey>(privateKey),
          _secureRandom,
        ),
      );

      final signature = signer.generateSignature(content) as RSASignature;
      return signature.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
    } catch (e) {
      return null;
    }
  }

  bool _verifySignature(
    Uint8List content,
    String? signatureHex,
    RSAPublicKey publicKey,
  ) {
    if (signatureHex == null || signatureHex.isEmpty) return true;

    try {
      final signer = Signer('SHA-256/RSA');
      signer.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

      final signature = RSASignature(_hexDecode(signatureHex));
      return signer.verifySignature(content, signature);
    } catch (e) {
      return false;
    }
  }

  String _generateHmac(Uint8List content, Uint8List key) {
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(content);
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  bool _verifyHmac(Uint8List content, Uint8List key, String hmacHex) {
    return _generateHmac(content, key) == hmacHex;
  }

  Uint8List _hexDecode(String hex) {
    return Uint8List.fromList(
      List.generate(
        hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
  }
}
