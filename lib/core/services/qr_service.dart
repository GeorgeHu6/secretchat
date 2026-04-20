import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:qr_flutter/qr_flutter.dart';
import '../utils/constants.dart';

class QrService {
  String encodePublicKeyForQr(String publicKeyPem) {
    final compressed = publicKeyPem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();

    return '${Constants.qrKeyPrefix}$compressed';
  }

  String? decodePublicKeyFromQr(String qrData) {
    if (!qrData.startsWith(Constants.qrKeyPrefix)) {
      return null;
    }

    final base64Content = qrData.substring(Constants.qrKeyPrefix.length);

    final lines = <String>[];
    for (var i = 0; i < base64Content.length; i += 64) {
      final end = i + 64 > base64Content.length ? base64Content.length : i + 64;
      lines.add(base64Content.substring(i, end));
    }

    return '${Constants.pemHeaderRsaPublicKey}\n${lines.join('\n')}\n${Constants.pemFooterRsaPublicKey}';
  }

  Future<Uint8List?> generateQrCodeBytes(String data, {int size = 300}) async {
    try {
      final qrPainter = QrPainter(
        data: data,
        version: QrVersions.auto,
        gapless: false,
        color: const ui.Color(0xFF000000),
        emptyColor: const ui.Color(0xFFFFFFFF),
      );

      final byteData = await qrPainter.toImageData(size.toDouble());
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }
}

class QrScanResult {
  final bool success;
  final String? publicKeyPem;
  final String? error;

  QrScanResult.success(this.publicKeyPem) : success = true, error = null;

  QrScanResult.failure(this.error) : success = false, publicKeyPem = null;
}
