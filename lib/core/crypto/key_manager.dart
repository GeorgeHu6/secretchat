import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'models/key_pair.dart';
import '../utils/constants.dart';

class KeyManager {
  final Random _random = Random.secure();

  String generateKeyId() {
    final values = List<int>.generate(16, (_) => _random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<KeyPair> generateRsaKeyPair({int keySize = 2048}) async {
    // 使用更安全的随机种子生成 - Fortuna 需要 256 位（32 字节）密钥
    final secureRandom = SecureRandom('Fortuna');
    final seed = Uint8List.fromList(
      List.generate(32, (_) => _random.nextInt(256)), // 32 字节 = 256 位
    );
    secureRandom.seed(KeyParameter(seed));

    // RSA 密钥生成：使用标准的公钥指数 65537 (Fermat number F4)
    final keyGenerator = RSAKeyGenerator();
    keyGenerator.init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(
          BigInt.from(65537), // 公钥指数，必须是奇数
          keySize, // 密钥长度
          64, // Miller-Rabin 测试迭代次数
        ),
        secureRandom,
      ),
    );

    final keyPair = keyGenerator.generateKeyPair();
    final publicKey = keyPair.publicKey as RSAPublicKey;
    final privateKey = keyPair.privateKey as RSAPrivateKey;

    // 编码为 PEM 格式
    final publicKeyPem = _encodePublicKeyPem(publicKey);
    final privateKeyPem = _encodePrivateKeyPem(privateKey);

    return KeyPair(
      id: generateKeyId(),
      algorithm: KeyAlgorithm.rsa,
      keySize: keySize,
      publicKeyPem: publicKeyPem,
      privateKeyPem: privateKeyPem,
      createdAt: DateTime.now(),
    );
  }

  Future<KeyPair> generateEccKeyPair() async {
    final secureRandom = SecureRandom('Fortuna');
    final seed = Uint8List.fromList(
      List.generate(32, (_) => _random.nextInt(256)),
    );
    secureRandom.seed(KeyParameter(seed));

    final keyGenerator = ECKeyGenerator();
    keyGenerator.init(
      ParametersWithRandom(
        ECKeyGeneratorParameters(ECCurve_secp256r1()),
        secureRandom,
      ),
    );

    final keyPair = keyGenerator.generateKeyPair();
    final publicKey = keyPair.publicKey as ECPublicKey;
    final privateKey = keyPair.privateKey as ECPrivateKey;

    final publicKeyPem = _encodeEcPublicKeyPem(publicKey);
    final privateKeyPem = _encodeEcPrivateKeyPem(privateKey);

    return KeyPair(
      id: generateKeyId(),
      algorithm: KeyAlgorithm.ecc,
      keySize: 256,
      publicKeyPem: publicKeyPem,
      privateKeyPem: privateKeyPem,
      createdAt: DateTime.now(),
    );
  }

  String _encodeEcPublicKeyPem(ECPublicKey publicKey) {
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

  String _encodeEcPrivateKeyPem(ECPrivateKey privateKey) {
    final dBytes = _bigIntToBytes(privateKey.d!);
    final version = _encodeDerInteger([1]);

    final privateKeyBytes = _encodeDerOctetString(dBytes);

    final curveOidBytes = [
      0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07,
    ];
    final curveOid = _encodeDerContextSpecific(0, curveOidBytes);

    final curve = ECCurve_secp256r1();
    final publicKeyPoint = curve.G * privateKey.d!;
    final publicKeyBytes = publicKeyPoint?.getEncoded(false) ?? Uint8List(0);
    final publicKey = _encodeDerContextSpecific(1, publicKeyBytes);

    final content = [...version, ...privateKeyBytes, ...curveOid, ...publicKey];
    final sequence = _encodeDerSequence(content);

    final base64Str = base64Encode(sequence);
    return _formatPem(
      base64Str,
      Constants.pemHeaderEcPrivateKey,
      Constants.pemFooterEcPrivateKey,
    );
  }

  List<int> _encodeDerOctetString(List<int> content) {
    final lengthBytes = _encodeDerLength(content.length);
    return [0x04, ...lengthBytes, ...content];
  }

  List<int> _encodeDerContextSpecific(int tag, List<int> content) {
    final lengthBytes = _encodeDerLength(content.length);
    return [0xA0 + tag, ...lengthBytes, ...content];
  }

  String _encodePublicKeyPem(RSAPublicKey publicKey) {
    final modulusBytes = _bigIntToBytes(publicKey.n!);
    final exponentBytes = _bigIntToBytes(publicKey.exponent!);

    final modulusDer = _encodeDerInteger(modulusBytes);
    final exponentDer = _encodeDerInteger(exponentBytes);

    final rsaKeyContent = [...modulusDer, ...exponentDer];
    final rsaKeySequence = _encodeDerSequence(rsaKeyContent);

    final oidBytes = [
      0x06,
      0x09,
      0x2A,
      0x86,
      0x48,
      0x86,
      0xF7,
      0x0D,
      0x01,
      0x01,
      0x01,
    ];
    final nullBytes = [0x05, 0x00];
    final algorithmId = _encodeDerSequence([...oidBytes, ...nullBytes]);

    final bitStringContent = [0x00, ...rsaKeySequence];
    final bitString = _encodeDerBitString(bitStringContent);

    final spkiContent = [...algorithmId, ...bitString];
    final spkiSequence = _encodeDerSequence(spkiContent);

    final base64Str = base64Encode(spkiSequence);
    return _formatPem(
      base64Str,
      Constants.pemHeaderRsaPublicKey,
      Constants.pemFooterRsaPublicKey,
    );
  }

  List<int> _encodeDerBitString(List<int> content) {
    final lengthBytes = _encodeDerLength(content.length);
    return [0x03, ...lengthBytes, ...content];
  }

  String _encodePrivateKeyPem(RSAPrivateKey privateKey) {
    // PKCS#1 RSAPrivateKey 格式
    final version = _encodeDerInteger(_bigIntToBytes(BigInt.zero));
    final modulus = _encodeDerInteger(_bigIntToBytes(privateKey.n!));
    final publicExponent = _encodeDerInteger(
      _bigIntToBytes(BigInt.from(65537)),
    );
    final privateExponent = _encodeDerInteger(_bigIntToBytes(privateKey.d!));
    final prime1 = _encodeDerInteger(_bigIntToBytes(privateKey.p!));
    final prime2 = _encodeDerInteger(_bigIntToBytes(privateKey.q!));

    final pMinus1 = privateKey.p! - BigInt.one;
    final qMinus1 = privateKey.q! - BigInt.one;
    final dp = privateKey.d! % pMinus1;
    final dq = privateKey.d! % qMinus1;
    final coefficient = privateKey.q!.modInverse(privateKey.p!);

    final exponent1 = _encodeDerInteger(_bigIntToBytes(dp));
    final exponent2 = _encodeDerInteger(_bigIntToBytes(dq));
    final coeff = _encodeDerInteger(_bigIntToBytes(coefficient));

    final content = [
      ...version,
      ...modulus,
      ...publicExponent,
      ...privateExponent,
      ...prime1,
      ...prime2,
      ...exponent1,
      ...exponent2,
      ...coeff,
    ];

    final sequence = _encodeDerSequence(content);

    final base64Str = base64Encode(sequence);
    return _formatPem(
      base64Str,
      Constants.pemHeaderRsaPrivateKey,
      Constants.pemFooterRsaPrivateKey,
    );
  }

  List<int> _encodeDerSequence(List<int> content) {
    // SEQUENCE tag = 0x30
    final lengthBytes = _encodeDerLength(content.length);
    return [0x30, ...lengthBytes, ...content];
  }

  List<int> _encodeDerInteger(List<int> value) {
    // INTEGER tag = 0x02
    // 如果最高位是 1，需要添加前导 0
    if (value.isNotEmpty && (value[0] & 0x80) != 0) {
      value = [0, ...value];
    }
    final lengthBytes = _encodeDerLength(value.length);
    return [0x02, ...lengthBytes, ...value];
  }

  List<int> _encodeDerLength(int length) {
    if (length < 128) {
      return [length];
    }

    // 长编码形式
    final lengthBytes = _intToBytes(length);
    return [0x80 | lengthBytes.length, ...lengthBytes];
  }

  List<int> _intToBytes(int value) {
    if (value == 0) return [0];

    final bytes = <int>[];
    var remaining = value;

    while (remaining > 0) {
      bytes.insert(0, remaining & 0xFF);
      remaining >>= 8;
    }

    return bytes;
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

  String _formatPem(String base64, String header, String footer) {
    final lines = <String>[];
    for (var i = 0; i < base64.length; i += 64) {
      final end = i + 64;
      lines.add(base64.substring(i, end > base64.length ? base64.length : end));
    }
    return '$header\n${lines.join('\n')}\n$footer';
  }

  bool validatePemFormat(String pem, {bool requirePrivateKey = false}) {
    if (pem.isEmpty) return false;

    final hasRsaPublicKeyHeader = pem.contains(Constants.pemHeaderRsaPublicKey);
    final hasRsaPrivateKeyHeader = pem.contains(Constants.pemHeaderRsaPrivateKey);
    final hasEcPublicKeyHeader = pem.contains(Constants.pemHeaderEcPublicKey);
    final hasEcPrivateKeyHeader = pem.contains(Constants.pemHeaderEcPrivateKey);

    if (requirePrivateKey) {
      return (hasRsaPrivateKeyHeader &&
              pem.contains(Constants.pemFooterRsaPrivateKey)) ||
          (hasEcPrivateKeyHeader &&
              pem.contains(Constants.pemFooterEcPrivateKey));
    }

    return (hasRsaPublicKeyHeader &&
            pem.contains(Constants.pemFooterRsaPublicKey)) ||
        (hasRsaPrivateKeyHeader &&
            pem.contains(Constants.pemFooterRsaPrivateKey)) ||
        (hasEcPublicKeyHeader &&
            pem.contains(Constants.pemFooterEcPublicKey)) ||
        (hasEcPrivateKeyHeader &&
            pem.contains(Constants.pemFooterEcPrivateKey));
  }

  bool isEccKey(String pem) {
    if (pem.contains(Constants.pemHeaderEcPrivateKey)) {
      return true;
    }
    if (pem.contains(Constants.pemHeaderRsaPrivateKey)) {
      return false;
    }

    if (pem.contains(Constants.pemHeaderRsaPublicKey)) {
      return _isEcPublicKeyByOid(pem);
    }

    return false;
  }

  bool _isEcPublicKeyByOid(String pem) {
    try {
      final base64 = _extractBase64FromPem(pem);
      final decoded = base64Decode(base64);

      if (decoded.isEmpty || decoded[0] != 0x30) return false;

      var offset = 1;
      offset = _skipDerLengthBytes(decoded, offset);

      if (offset >= decoded.length || decoded[offset] != 0x30) return false;
      offset++;
      offset = _skipDerLengthBytes(decoded, offset);

      if (offset + 2 > decoded.length || decoded[offset] != 0x06) return false;

      final oidLen = decoded[offset + 1];
      if (offset + 2 + oidLen > decoded.length) return false;

      final oidBytes = decoded.sublist(offset + 2, offset + 2 + oidLen);

      final ecOid = [0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01];
      if (oidBytes.length >= ecOid.length) {
        for (var i = 0; i < ecOid.length; i++) {
          if (oidBytes[i] != ecOid[i]) return false;
        }
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  ECPublicKey? parseEcPublicKeyPem(String pem) {
    try {
      final base64 = _extractBase64FromPem(pem);
      final decoded = base64Decode(base64);

      if (decoded.isEmpty || decoded[0] != 0x30) return null;

      var offset = 1;
      offset = _skipDerLengthBytes(decoded, offset);

      if (offset >= decoded.length || decoded[offset] != 0x30) return null;
      offset++;
      offset = _skipDerLengthBytes(decoded, offset);

      if (offset + 2 > decoded.length || decoded[offset] != 0x06) return null;
      final oidLen = decoded[offset + 1];
      offset += 2 + oidLen;

      if (offset >= decoded.length) return null;
      if (decoded[offset] == 0x06) {
        final curveOidLen = decoded[offset + 1];
        offset += 2 + curveOidLen;
      }

      if (offset >= decoded.length || decoded[offset] != 0x03) return null;
      offset++;
      offset = _skipDerLengthBytes(decoded, offset);

      if (decoded[offset] != 0x00) return null;
      offset++;

      final pointBytes = decoded.sublist(offset);
      final curve = ECCurve_secp256r1();
      final point = curve.curve.decodePoint(pointBytes);

      return ECPublicKey(point, curve);
    } catch (e) {
      return null;
    }
  }

  ECPrivateKey? parseEcPrivateKeyPem(String pem) {
    try {
      final base64 = _extractBase64FromPem(pem);
      final decoded = base64Decode(base64);

      if (decoded.isEmpty || decoded[0] != 0x30) return null;

      var offset = 1;
      offset = _skipDerLengthBytes(decoded, offset);

      if (offset >= decoded.length || decoded[offset] != 0x02) return null;
      offset++;
      final versionLen = _readDerLength(decoded, offset);
      offset = _skipDerLengthBytes(decoded, offset) + versionLen;

      if (offset >= decoded.length || decoded[offset] != 0x04) return null;
      offset++;
      final privateKeyLen = _readDerLength(decoded, offset);
      offset = _skipDerLengthBytes(decoded, offset);
      final privateKeyBytes = decoded.sublist(offset, offset + privateKeyLen);

      final d = _bytesToBigInt(privateKeyBytes);
      final curve = ECCurve_secp256r1();

      return ECPrivateKey(d, curve);
    } catch (e) {
      return null;
    }
  }

  RSAPublicKey? parsePublicKeyPem(String pem) {
    try {
      final base64 = _extractBase64FromPem(pem);
      final decoded = base64Decode(base64);

      if (decoded.isEmpty || decoded[0] != 0x30) {
        return null;
      }

      var offset = 1;
      offset = _skipDerLengthBytes(decoded, offset);

      if (offset >= decoded.length || decoded[offset] != 0x30) {
        return null;
      }
      offset++;
      offset = _skipDerLengthBytes(decoded, offset);

      if (offset + 2 > decoded.length) return null;
      if (decoded[offset] != 0x06) return null;
      final oidLen = decoded[offset + 1];
      offset += 2 + oidLen;

      if (offset >= decoded.length || decoded[offset] != 0x05) return null;
      offset += 2;

      if (offset >= decoded.length || decoded[offset] != 0x03) return null;
      offset++;
      final bitStringLen = _readDerLength(decoded, offset);
      offset = _skipDerLengthBytes(decoded, offset);

      if (decoded[offset] != 0x00) return null;
      offset++;

      if (offset >= decoded.length || decoded[offset] != 0x30) return null;
      offset++;
      offset = _skipDerLengthBytes(decoded, offset);

      if (offset >= decoded.length || decoded[offset] != 0x02) return null;
      offset++;
      final modulusLen = _readDerLength(decoded, offset);
      offset = _skipDerLengthBytes(decoded, offset);

      if (offset + modulusLen > decoded.length) return null;
      final modulusBytes = decoded.sublist(offset, offset + modulusLen);
      offset += modulusLen;

      if (offset >= decoded.length || decoded[offset] != 0x02) return null;
      offset++;
      final exponentLen = _readDerLength(decoded, offset);
      offset = _skipDerLengthBytes(decoded, offset);

      if (offset + exponentLen > decoded.length) return null;
      final exponentBytes = decoded.sublist(offset, offset + exponentLen);

      final modulus = _bytesToBigInt(modulusBytes);
      final exponent = _bytesToBigInt(exponentBytes);

      return RSAPublicKey(modulus, exponent);
    } catch (e) {
      return null;
    }
  }

  RSAPrivateKey? parsePrivateKeyPem(String pem) {
    try {
      final base64 = _extractBase64FromPem(pem);
      final decoded = base64Decode(base64);

      // 解析 DER SEQUENCE
      if (decoded[0] != 0x30) return null;

      var offset = 1;
      offset = _skipDerLength(decoded, offset);

      // 跳过 version
      if (decoded[offset] != 0x02) return null;
      offset++;
      final versionLen = _readDerLength(decoded, offset);
      offset = _skipDerLengthBytes(decoded, offset) + versionLen;

      // 解析 modulus
      if (decoded[offset] != 0x02) return null;
      offset++;
      final modulusLen = _readDerLength(decoded, offset);
      offset = _skipDerLengthBytes(decoded, offset);
      final modulusBytes = decoded.sublist(offset, offset + modulusLen);
      offset += modulusLen;

      // 解析 public exponent
      if (decoded[offset] != 0x02) return null;
      offset++;
      final pubExpLen = _readDerLength(decoded, offset);
      offset = _skipDerLengthBytes(decoded, offset) + pubExpLen;

      // 解析 private exponent
      if (decoded[offset] != 0x02) return null;
      offset++;
      final privExpLen = _readDerLength(decoded, offset);
      offset = _skipDerLengthBytes(decoded, offset);
      final privExpBytes = decoded.sublist(offset, offset + privExpLen);
      offset += privExpLen;

      // 解析 prime1 (p)
      if (decoded[offset] != 0x02) return null;
      offset++;
      final pLen = _readDerLength(decoded, offset);
      offset = _skipDerLengthBytes(decoded, offset);
      final pBytes = decoded.sublist(offset, offset + pLen);
      offset += pLen;

      // 解析 prime2 (q)
      if (decoded[offset] != 0x02) return null;
      offset++;
      final qLen = _readDerLength(decoded, offset);
      offset = _skipDerLengthBytes(decoded, offset);
      final qBytes = decoded.sublist(offset, offset + qLen);

      final modulus = _bytesToBigInt(modulusBytes);
      final privateExponent = _bytesToBigInt(privExpBytes);
      final p = _bytesToBigInt(pBytes);
      final q = _bytesToBigInt(qBytes);

      return RSAPrivateKey(modulus, privateExponent, p, q);
    } catch (e) {
      return null;
    }
  }

  String _extractBase64FromPem(String pem) {
    final lines = pem.split('\n');
    return lines.where((line) => !line.startsWith('-----')).join();
  }

  int _readDerLength(List<int> bytes, int offset) {
    final firstByte = bytes[offset];
    if (firstByte < 128) {
      return firstByte;
    }

    final numBytes = firstByte & 0x7F;
    var length = 0;
    for (var i = 0; i < numBytes; i++) {
      length = (length << 8) | bytes[offset + 1 + i];
    }
    return length;
  }

  int _skipDerLength(List<int> bytes, int offset) {
    final firstByte = bytes[offset];
    if (firstByte < 128) {
      return offset + 1;
    }
    return offset + 1 + (firstByte & 0x7F);
  }

  int _skipDerLengthBytes(List<int> bytes, int offset) {
    final firstByte = bytes[offset];
    if (firstByte < 128) {
      return offset + 1;
    }
    return offset + 1 + (firstByte & 0x7F);
  }

  BigInt _bytesToBigInt(List<int> bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  KeyPair parseRsaPrivateKeyPem(String pem) {
    final privateKey = parsePrivateKeyPem(pem);
    if (privateKey == null) {
      throw Exception('Failed to parse private key');
    }

    // 使用正确的公钥指数（不是私钥指数）
    final publicKeyPem = _encodePublicKeyPem(
      RSAPublicKey(
        privateKey.n!,
        privateKey.publicExponent ?? BigInt.from(65537),
      ),
    );

    return KeyPair(
      id: generateKeyId(),
      algorithm: KeyAlgorithm.rsa,
      keySize: privateKey.n!.bitLength,
      publicKeyPem: publicKeyPem,
      privateKeyPem: pem,
      createdAt: DateTime.now(),
    );
  }

  String extractPublicKeyPem(String pem) {
    if (pem.contains(Constants.pemHeaderRsaPrivateKey)) {
      final keyPair = parseRsaPrivateKeyPem(pem);
      return keyPair.publicKeyPem;
    }
    return pem;
  }
}
