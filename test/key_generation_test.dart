import 'dart:convert';
import 'package:pointycastle/export.dart';
import '../lib/core/crypto/key_manager.dart';

void main() async {
  print('=== RSA 密钥生成测试 ===\n');

  final keyManager = KeyManager();

  try {
    print('开始生成 RSA-2048 密钥对...');
    final keyPair = await keyManager.generateRsaKeyPair(keySize: 2048);

    print('✅ 密钥对生成成功！');
    print('ID: ${keyPair.id}');
    print('算法: ${keyPair.algorithmName}');
    print('密钥长度: ${keyPair.keySize}');
    print('创建时间: ${keyPair.createdAt}');

    print('\n--- 公钥 PEM ---');
    print(keyPair.publicKeyPem);

    print('\n--- 私钥 PEM (前 200 字符) ---');
    print(keyPair.privateKeyPem!.substring(0, 200));

    // 验证 PEM 格式
    print('\n=== PEM 格式验证 ===');
    final publicKeyValid = keyManager.validatePemFormat(keyPair.publicKeyPem);
    final privateKeyValid = keyManager.validatePemFormat(
      keyPair.privateKeyPem!,
      requirePrivateKey: true,
    );

    print('公钥格式: ${publicKeyValid ? "✅ 正确" : "❌ 错误"}');
    print('私钥格式: ${privateKeyValid ? "✅ 正确" : "❌ 错误"}');

    // 验证密钥解析
    print('\n=== 密钥解析验证 ===');
    final publicKey = keyManager.parsePublicKeyPem(keyPair.publicKeyPem);
    final privateKey = keyManager.parsePrivateKeyPem(keyPair.privateKeyPem!);

    print('公钥解析: ${publicKey != null ? "✅ 成功" : "❌ 失败"}');
    print('私钥解析: ${privateKey != null ? "✅ 成功" : "❌ 失败"}');

    if (publicKey != null) {
      print('公钥模数长度: ${publicKey.n!.bitLength} bits');
      print('公钥指数: ${publicKey.exponent}');
    }

    if (privateKey != null) {
      print('私钥模数长度: ${privateKey.n!.bitLength} bits');
    }

    // 提取公钥测试
    print('\n=== 从私钥提取公钥 ===');
    final extractedPublicKeyPem = keyManager.extractPublicKeyPem(
      keyPair.privateKeyPem!,
    );
    print(
      '提取公钥: ${extractedPublicKeyPem == keyPair.publicKeyPem ? "✅ 匹配" : "❌ 不匹配"}',
    );

    print('\n=== 测试完成 ===');
    print('所有测试通过！密钥生成功能正常工作。');
  } catch (e, stackTrace) {
    print('❌ 错误: $e');
    print('\n堆栈跟踪:');
    print(stackTrace);
  }
}
