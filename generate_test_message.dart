import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'lib/core/crypto/key_manager.dart';
import 'lib/core/crypto/encryption_service.dart';
import 'lib/core/crypto/models/encrypted_message.dart';

void main() async {
  final keyManager = KeyManager();
  final encryptionService = EncryptionService();

  print('=== 测试消息生成工具 ===\n');
  print('此工具用于生成测试数据，验证应用的加密解密功能。\n');
  print('场景说明：');
  print('1. 你（本地用户）需要导入私钥到应用，用于解密接收的消息');
  print('2. 联系人需要导入公钥到应用，用于加密发送给联系人的消息');
  print('3. 模拟联系人发消息给你：用你的公钥加密，联系人私钥签名\n');

  print('─' * 60);

  // 生成你的密钥对（本地用户）
  print('\n【1. 你的密钥对】（导入到应用本地）');
  print('─' * 60);
  final myKeyPair = await keyManager.generateRsaKeyPair();

  print('\n你的私钥（导入到应用 → 密钥管理 → 导入私钥）:');
  print(myKeyPair.privateKeyPem);
  // print('┌' + '─' * 58 + '┐');
  // for (final line in myKeyPair.privateKeyPem!.split('\n')) {
  //   print('│ $line');
  // }
  // print('└' + '─' * 58 + '┘');

  print('\n你的公钥（可选导出，用于分享给他人）:');
  print(myKeyPair.publicKeyPem);
  // print('┌' + '─' * 58 + '┐');
  // for (final line in myKeyPair.publicKeyPem.split('\n')) {
  //   print('│ $line');
  // }
  // print('└' + '─' * 58 + '┘');

  // 生成联系人的密钥对
  print('\n【2. 联系人密钥对】（模拟对方）');
  print('─' * 60);
  final contactKeyPair = await keyManager.generateRsaKeyPair();

  print('\n联系人公钥（添加联系人时使用）:');
  print(contactKeyPair.publicKeyPem);
  // print('┌' + '─' * 58 + '┐');
  // for (final line in contactKeyPair.publicKeyPem.split('\n')) {
  //   print('│ $line');
  // }
  // print('└' + '─' * 58 + '┘');

  // 生成加密消息（模拟联系人发给你）
  print('\n【3. 加密测试消息】（模拟联系人发送给你）');
  print('─' * 60);

  final testMessage = '这是一条来自联系人的测试消息！Hello SecretChat! 🔐';

  print('\n原文: "$testMessage"');
  print('\n加密参数:');
  print('  - 接收方公钥（你的公钥）: 用于加密 AES 密钥');
  print('  - 发送方私钥（联系人私钥）: 用于 RSA-SHA256 签名');
  print('\n签名状态: ✅ 已启用（消息包含发送方数字签名）');

  final encrypted = await encryptionService.encryptText(
    testMessage,
    myKeyPair.publicKeyPem, // 你的公钥（你是接收方）
    contactKeyPair.privateKeyPem!, // 联系人私钥（联系人是发送方）
  );

  final ciphertext = encrypted.encode();

  print('\n密文（导入消息时使用）:');
  print(ciphertext);
  // print('┌' + '─' * 58 + '┐');
  // // 分行显示长密文
  // final chunks = _splitString(ciphertext, 54);
  // for (final chunk in chunks) {
  //   print('│ $chunk');
  // }
  // print('└' + '─' * 58 + '┘');

  // 验证解密
  print('\n【4. 验证解密】');
  print('─' * 60);

  try {
    final decrypted = await encryptionService.decryptText(
      encrypted,
      myKeyPair.privateKeyPem!, // 你的私钥解密
      contactKeyPair.publicKeyPem, // 联系人公钥验证签名
    );
    print('解密结果: "$decrypted"');
    print('签名验证: ✅ 通过（发送方身份已确认）');
    print(decrypted == testMessage ? '✅ 解密验证成功！' : '❌ 解密验证失败');
  } catch (e) {
    print('❌ 解密失败: $e');
  }

  // 使用说明
  print('\n【5. 使用说明】');
  print('─' * 60);
  print('步骤 1: 导入你的私钥');
  print('  - 进入应用 → 密钥管理');
  print('  - 点击"导入私钥"按钮');
  print('  - 粘贴上面【1. 你的密钥对】中的私钥\n');

  print('步骤 2: 添加联系人');
  print('  - 进入应用主界面 → 点击 + 按钮');
  print('  - 输入联系人名称（如：TestContact）');
  print('  - 粘贴上面【2. 联系人密钥对】中的公钥\n');

  print('步骤 3: 导入测试消息');
  print('  - 进入联系人聊天界面');
  print('  - 点击导入按钮（文件图标）');
  print('  - 粘贴上面【3. 加密测试消息】中的密文\n');

  print('步骤 4: 查看解密结果');
  print('  - 应用会自动解密并显示消息内容');
  print('  - 应显示: "$testMessage"\n');

  print('─' * 60);
  print('测试完成！');
}

List<String> _splitString(String s, int chunkSize) {
  final result = <String>[];
  for (var i = 0; i < s.length; i += chunkSize) {
    final end = i + chunkSize > s.length ? s.length : i + chunkSize;
    result.add(s.substring(i, end));
  }
  return result;
}
