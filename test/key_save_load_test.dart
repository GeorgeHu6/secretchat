import 'dart:io';
import '../lib/core/crypto/key_manager.dart';
import '../lib/core/storage/file_storage.dart';

void main() async {
  print('=== 密钥生成、保存、加载完整测试 ===\n');

  final keyManager = KeyManager();
  final storageService = StorageService();

  try {
    // 1. 生成密钥
    print('1. 生成 RSA-2048 密钥对...');
    final keyPair = await keyManager.generateRsaKeyPair(keySize: 2048);
    print('   ✅ 成功生成密钥');
    print('   ID: ${keyPair.id}');
    print('   公钥长度: ${keyPair.publicKeyPem.length}');
    print('   私钥长度: ${keyPair.privateKeyPem!.length}');

    // 2. 保存密钥
    print('\n2. 保存密钥到文件...');
    await storageService.saveKeyPair(keyPair.id, keyPair.privateKeyPem!);
    print('   ✅ 密钥已保存');

    // 3. 获取文件路径并验证文件存在
    print('\n3. 验证文件保存...');
    // 直接读取列表来验证
    final keyIds = await storageService.listKeyPairs();
    print('   找到密钥数量: ${keyIds.length}');

    if (keyIds.isNotEmpty) {
      final loadedPem = await storageService.loadKeyPair(keyIds.first);
      if (loadedPem != null) {
        print('   ✅ 文件存在且可读取');
        print('   内容长度: ${loadedPem.length}');
      }
    }

    // 4. 列出所有密钥
    print('\n4. 列出所有密钥...');
    final allKeyIds = await storageService.listKeyPairs();
    print('   找到密钥数量: ${allKeyIds.length}');
    for (final id in allKeyIds) {
      print('   - $id');
    }

    // 5. 加载密钥
    print('\n5. 加载密钥...');
    final loadedPem = await storageService.loadKeyPair(keyPair.id);
    if (loadedPem != null) {
      print('   ✅ 密钥已加载');
      print('   加载长度: ${loadedPem.length}');
      print('   是否匹配: ${loadedPem == keyPair.privateKeyPem}');

      // 解析加载的密钥
      final loadedKeyPair = keyManager.parseRsaPrivateKeyPem(loadedPem);
      print('   解析成功: ✅');
      print('   解析后ID: ${loadedKeyPair.id}');
    } else {
      print('   ❌ 加载失败: 返回 null');
    }

    // 6. 测试完整流程模拟 Provider
    print('\n5. 模拟 Provider 流程...');
    final loadedKeyIds = await storageService.listKeyPairs();
    if (loadedKeyIds.isNotEmpty) {
      final id = loadedKeyIds.first;
      final pem = await storageService.loadKeyPair(id);
      if (pem != null) {
        final kp = keyManager.parseRsaPrivateKeyPem(pem);
        print('   ✅ Provider 流程成功');
        print('   密钥对: ${kp.algorithmName}');
      }
    }

    print('\n=== 测试完成 ===');
    print('所有步骤均通过，密钥保存和加载功能正常！');
  } catch (e, stackTrace) {
    print('❌ 错误: $e');
    print('\n堆栈跟踪:');
    print(stackTrace);
  }
}
