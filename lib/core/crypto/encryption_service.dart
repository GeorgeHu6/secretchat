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
    final isEcc = _keyManager.isEccKey(recipientPublicKeyPem);

    if (isEcc) {
      return _encryptWithEcies(
        content,
        type,
        recipientPublicKeyPem,
        senderPrivateKeyPem,
        fileName: fileName,
        fileSize: fileSize,
      );
    } else {
      return _encryptWithRsa(
        content,
        type,
        recipientPublicKeyPem,
        senderPrivateKeyPem,
        fileName: fileName,
        fileSize: fileSize,
      );
    }
  }

  Future<EncryptedMessage> _encryptWithRsa(
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

  Future<EncryptedMessage> _encryptWithEcies(
    Uint8List content,
    MessageType type,
    String recipientPublicKeyPem,
    String senderPrivateKeyPem, {
    String? fileName,
    int? fileSize,
  }) async {
    final recipientPublicKey = _keyManager.parseEcPublicKeyPem(
      recipientPublicKeyPem,
    );

    if (recipientPublicKey == null) {
      throw Exception('Invalid recipient ECC public key');
    }

    final secureRandom = SecureRandom('Fortuna');
    secureRandom.seed(
      KeyParameter(
        Uint8List.fromList(List.generate(32, (_) => _random.nextInt(256))),
      ),
    );

    final keyGenerator = ECKeyGenerator();
    keyGenerator.init(
      ParametersWithRandom(
        ECKeyGeneratorParameters(ECCurve_secp256r1()),
        secureRandom,
      ),
    );

    final ephemeralPair = keyGenerator.generateKeyPair();
    final ephemeralPrivateKey = ephemeralPair.privateKey as ECPrivateKey;
    final ephemeralPublicKey = ephemeralPair.publicKey as ECPublicKey;

    final sharedSecret = _computeEcdhSharedSecret(
      ephemeralPrivateKey,
      recipientPublicKey,
    );

    final aesKeyBytes = _deriveAesKeyFromSharedSecret(sharedSecret);
    final ivBytes = _generateRandomBytes(12);

    final aesKey = pkg.Key(aesKeyBytes);
    final iv = pkg.IV(ivBytes);

    final encrypter = pkg.Encrypter(pkg.AES(aesKey, mode: pkg.AESMode.gcm));
    final encrypted = encrypter.encryptBytes(content, iv: iv);

    final ivAndEncrypted = Uint8List.fromList([...ivBytes, ...encrypted.bytes]);

    final ephemeralPublicKeyBytes = ephemeralPublicKey.Q!.getEncoded(false);

    final signature = _signContent(content, senderPrivateKeyPem);
    final hmac = _generateHmac(content, aesKeyBytes);

    return EncryptedMessage(
      encryptedContent: ivAndEncrypted,
      encryptedAesKey: ephemeralPublicKeyBytes,
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

  Uint8List _computeEcdhSharedSecret(
    ECPrivateKey privateKey,
    ECPublicKey publicKey,
  ) {
    final sharedPoint = publicKey.Q! * privateKey.d!;
    final sharedX = sharedPoint?.x?.toBigInteger() ?? BigInt.zero;
    return _bigIntToBytes(sharedX);
  }

  Uint8List _deriveAesKeyFromSharedSecret(Uint8List sharedSecret) {
    final kdf = HMac(SHA256Digest(), 64);
    kdf.init(KeyParameter(sharedSecret));

    final derivedKey = Uint8List(32);
    kdf.update(derivedKey, 0, derivedKey.length);
    return derivedKey;
  }

  String _signContentEcdsa(Uint8List content, String privateKeyPem) {
    try {
      final privateKey = _keyManager.parseEcPrivateKeyPem(privateKeyPem);
      if (privateKey == null) return '';

      final signer = Signer('SHA-256/ECDSA');
      signer.init(
        true,
        ParametersWithRandom<PrivateKeyParameter<ECPrivateKey>>(
          PrivateKeyParameter<ECPrivateKey>(privateKey),
          _secureRandom,
        ),
      );

      final signature = signer.generateSignature(content) as ECSignature;
      final rBytes = _bigIntToBytes(signature.r);
      final sBytes = _bigIntToBytes(signature.s);
      final combined = Uint8List.fromList([...rBytes, ...sBytes]);
      return combined.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      return '';
    }
  }

  bool _verifySignatureEcdsa(
    Uint8List content,
    String signatureHex,
    ECPublicKey publicKey,
  ) {
    try {
      final signatureBytes = _hexDecode(signatureHex);
      final r = _bytesToBigInt(signatureBytes.sublist(0, signatureBytes.length ~/ 2));
      final s = _bytesToBigInt(signatureBytes.sublist(signatureBytes.length ~/ 2));

      final signature = ECSignature(r, s);

      final signer = Signer('SHA-256/ECDSA');
      signer.init(false, PublicKeyParameter<ECPublicKey>(publicKey));

      return signer.verifySignature(content, signature);
    } catch (e) {
      return false;
    }
  }

  Uint8List _bigIntToBytes(BigInt bigInt) {
    if (bigInt == BigInt.zero) return Uint8List.fromList([0]);

    var hex = bigInt.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';

    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }

    return bytes;
  }

  BigInt _bytesToBigInt(List<int> bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
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
    final isEcc = _keyManager.isEccKey(recipientPrivateKeyPem);

    if (isEcc) {
      return _decryptWithEcies(message, recipientPrivateKeyPem, senderPublicKeyPem);
    } else {
      return _decryptWithRsa(message, recipientPrivateKeyPem, senderPublicKeyPem);
    }
  }

  Future<Uint8List> _decryptWithRsa(
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
      if (!_verifySignature(decrypted, message.signature, senderPublicKeyPem)) {
        throw Exception('签名验证失败 - 消息可能被篡改或发送方身份不匹配');
      }
    }

    if (!_verifyHmac(decrypted, aesKeyBytes, message.hmac)) {
      throw Exception('HMAC验证失败 - 消息完整性受损');
    }

    return decrypted;
  }

  Future<Uint8List> _decryptWithEcies(
    EncryptedMessage message,
    String recipientPrivateKeyPem,
    String senderPublicKeyPem,
  ) async {
    final privateKey = _keyManager.parseEcPrivateKeyPem(recipientPrivateKeyPem);
    if (privateKey == null) throw Exception('Invalid ECC private key');

    final ephemeralPublicKeyBytes = message.encryptedAesKey;
    final curve = ECCurve_secp256r1();
    final ephemeralPublicKey = ECPublicKey(
      curve.curve.decodePoint(ephemeralPublicKeyBytes),
      curve,
    );

    final sharedSecret = _computeEcdhSharedSecret(privateKey, ephemeralPublicKey);
    final aesKeyBytes = _deriveAesKeyFromSharedSecret(sharedSecret);

    final ivBytes = message.encryptedContent.sublist(0, 12);
    final encryptedBytes = message.encryptedContent.sublist(12);

    final aesKey = pkg.Key(aesKeyBytes);
    final iv = pkg.IV(ivBytes);
    final encrypter = pkg.Encrypter(pkg.AES(aesKey, mode: pkg.AESMode.gcm));

    final decrypted = Uint8List.fromList(
      encrypter.decryptBytes(pkg.Encrypted(encryptedBytes), iv: iv),
    );

    if (message.signature != null && message.signature!.isNotEmpty) {
      if (!_verifySignature(decrypted, message.signature!, senderPublicKeyPem)) {
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
    if (_keyManager.isEccKey(privateKeyPem)) {
      return _signContentEcdsa(content, privateKeyPem);
    } else {
      return _signContentRsa(content, privateKeyPem);
    }
  }

  bool _verifySignature(
    Uint8List content,
    String? signatureHex,
    String publicKeyPem,
  ) {
    if (signatureHex == null || signatureHex.isEmpty) return true;

    if (_keyManager.isEccKey(publicKeyPem)) {
      final publicKey = _keyManager.parseEcPublicKeyPem(publicKeyPem);
      if (publicKey == null) return false;
      return _verifySignatureEcdsa(content, signatureHex, publicKey);
    } else {
      final publicKey = _keyManager.parsePublicKeyPem(publicKeyPem);
      if (publicKey == null) return false;
      return _verifySignatureRsa(content, signatureHex, publicKey);
    }
  }

  String? _signContentRsa(Uint8List content, String privateKeyPem) {
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

  bool _verifySignatureRsa(
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
