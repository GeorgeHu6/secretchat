import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
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
            subtitle: const Text('SecretChat v0.1.0'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'SecretChat',
                applicationVersion: '0.1.0',
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
        ],
      ),
    );
  }
}
