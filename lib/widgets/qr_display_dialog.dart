import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/services/qr_service.dart';

class QrDisplayDialog extends StatelessWidget {
  final String publicKeyPem;
  final String title;

  const QrDisplayDialog({
    super.key,
    required this.publicKeyPem,
    this.title = '公钥二维码',
  });

  @override
  Widget build(BuildContext context) {
    final qrService = QrService();
    final qrData = qrService.encodePublicKeyForQr(publicKeyPem);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.qr_code, color: Colors.blue),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '扫描此二维码可导入公钥',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
