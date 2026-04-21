import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/key_provider.dart';
import '../../providers/contact_provider.dart';
import 'key_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('密钥管理'),
            subtitle: const Text('生成、导入、导出密钥'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const KeyManagementScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.contacts),
            title: const Text('联系人管理'),
            subtitle: const Text('添加、编辑联系人'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            subtitle: const Text('SecretChat v1.0.0'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'SecretChat',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 SecretChat',
                children: [
                  const SizedBox(height: 16),
                  const Text('基于非对称加密的安全聊天应用'),
                  const SizedBox(height: 8),
                  const Text('支持 RSA/ECC 加密、数字签名、HMAC 完整性验证'),
                ],
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock, color: Colors.orange),
            title: const Text('锁定密钥', style: TextStyle(color: Colors.orange)),
            subtitle: const Text('下次使用密钥需重新验证密码'),
            onTap: () {
              context.read<AuthProvider>().lockKeys();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已锁定，下次使用密钥时需要验证密码')),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('清空所有数据', style: TextStyle(color: Colors.red)),
            subtitle: const Text('删除所有密钥、联系人、消息和主密码'),
            onTap: () => _showClearDataDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showClearDataDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('清空所有数据'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('此操作将永久删除以下数据：'),
            SizedBox(height: 12),
            Text('• 所有密钥对'),
            Text('• 所有联系人'),
            Text('• 所有聊天消息'),
            Text('• 主密码'),
            SizedBox(height: 16),
            Text(
              '此操作不可恢复！',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authProvider = context.read<AuthProvider>();
    final passwordVerified = await authProvider.ensureKeyUnlocked(context);

    if (!passwordVerified) return;

    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('最后确认'),
        content: const Text('您确定要清空所有数据吗？\n应用将返回到初始状态。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确定清空'),
          ),
        ],
      ),
    );

    if (finalConfirm != true || !context.mounted) return;

    try {
      final keyProvider = context.read<KeyProvider>();
      final contactProvider = context.read<ContactProvider>();

      await authProvider.clearAllData();
      keyProvider.clearState();
      contactProvider.clearState();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('所有数据已清空')));

      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('清空失败：$e')));
      }
    }
  }
}
