import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/services/qr_service.dart';

class QrScannerDialog extends StatefulWidget {
  const QrScannerDialog({super.key});

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog> {
  final QrService _qrService = QrService();
  bool _isScanning = true;
  String? _errorMessage;

  void _handleDetection(BarcodeCapture capture) {
    if (!_isScanning) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null) return;

    final publicKeyPem = _qrService.decodePublicKeyFromQr(rawValue);
    if (publicKeyPem != null) {
      _isScanning = false;
      Navigator.pop(context, publicKeyPem);
    } else {
      setState(() {
        _errorMessage = '无效的公钥二维码';
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    '扫描二维码',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(onDetect: _handleDetection),
                  if (_errorMessage != null)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                '将公钥二维码放入框内',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
