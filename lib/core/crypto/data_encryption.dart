import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:pointycastle/export.dart';

class DataEncryption {
  static final Random _random = Random.secure();

  static Uint8List encryptData(Uint8List plaintext, Uint8List key) {
    if (key.length != 32) {
      throw ArgumentError('Key must be 32 bytes for AES-256');
    }

    final iv = _generateIV();
    final cipher = GCMBlockCipher(AESFastEngine());
    cipher.init(
      true,
      AEADParameters(
        KeyParameter(key),
        128,
        iv,
        Uint8List(0),
      ),
    );

    final ciphertext = cipher.process(plaintext);

    final result = Uint8List(iv.length + ciphertext.length);
    result.setAll(0, iv);
    result.setAll(iv.length, ciphertext);

    return result;
  }

  static Uint8List decryptData(Uint8List encryptedData, Uint8List key) {
    if (key.length != 32) {
      throw ArgumentError('Key must be 32 bytes for AES-256');
    }

    if (encryptedData.length < 12 + 16) {
      throw ArgumentError('Encrypted data too short');
    }

    final iv = encryptedData.sublist(0, 12);
    final ciphertext = encryptedData.sublist(12);

    final cipher = GCMBlockCipher(AESFastEngine());
    cipher.init(
      false,
      AEADParameters(
        KeyParameter(key),
        128,
        iv,
        Uint8List(0),
      ),
    );

    return cipher.process(ciphertext);
  }

  static String encryptString(String plaintext, Uint8List key) {
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
    final encrypted = encryptData(plaintextBytes, key);
    return base64Encode(encrypted);
  }

  static String decryptString(String encryptedBase64, Uint8List key) {
    final encryptedData = base64Decode(encryptedBase64);
    final decrypted = decryptData(encryptedData, key);
    return utf8.decode(decrypted);
  }

  static Uint8List _generateIV() {
    return Uint8List.fromList(
      List.generate(12, (_) => _random.nextInt(256)),
    );
  }
}