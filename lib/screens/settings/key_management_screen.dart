import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/key_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/crypto/models/key_pair.dart';
import '../../widgets/qr_display_dialog.dart';

class KeyManagementScreen extends StatefulWidget {
  const KeyManagementScreen({super.key});

  @override
  State<KeyManagementScreen> createState() => _KeyManagementScreenState();
}

class _KeyManagementScreenState extends State<KeyManagementScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadKeyPairs();
    });
  }

  Future<void> _loadKeyPairs() async {
    final authProvider = context.read<AuthProvider>();

    if (!authProvider.isKeyUnlocked) {
      final unlocked = await authProvider.ensureKeyUnlocked(context);
      if (!unlocked) {
        if (mounted) Navigator.pop(context);
        return;
      }
    }

    final keyProvider = context.read<KeyProvider>();
    await keyProvider.loadKeyPairs();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('密钥管理')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<KeyProvider>(
              builder: (context, keyProvider, child) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSection(
                      context,
                      title: '我的密钥对',
                      children: [
                        if (keyProvider.keyPairs.isEmpty)
                          const ListTile(
                            title: Text('暂无密钥对'),
                            subtitle: Text('点击下方按钮生成密钥'),
                          )
                        else
                          ...keyProvider.keyPairs.map(
                            (keyPair) =>
                                _buildKeyPairTile(context, keyProvider, keyPair),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _generateKeyPair(context, keyProvider),
                                icon: const Icon(Icons.add),
                                label: const Text('生成密钥'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _importKeyPair(context, keyProvider),
                                icon: const Icon(Icons.file_download),
                                label: const Text('导入私钥'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildKeyPairTile(
    BuildContext context,
    KeyProvider provider,
    KeyPair keyPair,
  ) {
    final isDefault = provider.defaultKeyPair?.id == keyPair.id;

    return Card(
      child: ListTile(
        leading: Icon(
          isDefault ? Icons.star : Icons.star_border,
          color: isDefault ? Colors.amber : Colors.grey,
        ),
        title: Text(keyPair.displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(keyPair.algorithmName),
            Text(
              '创建于 ${keyPair.createdAt.toString().split(' ')[0]}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) =>
              _handleKeyAction(context, provider, keyPair, value),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'rename', child: Text('重命名')),
            if (!isDefault)
              const PopupMenuItem(value: 'set_default', child: Text('设为默认')),
            const PopupMenuItem(value: 'show_qr', child: Text('二维码分享公钥')),
            const PopupMenuItem(value: 'export_public', child: Text('导出公钥文本')),
            const PopupMenuItem(value: 'export_private', child: Text('导出私钥')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateKeyPair(
    BuildContext context,
    KeyProvider provider,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final unlocked = await authProvider.ensureKeyUnlocked(context);

    if (!unlocked) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('生成密钥对'),
        content: const Text('确定要生成新的 RSA-2048 密钥对吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('生成'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await provider.generateKeyPair();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('密钥对生成成功')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('生成失败：$e')));
      }
    }
  }

  Future<void> _importKeyPair(
    BuildContext context,
    KeyProvider provider,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final unlocked = await authProvider.ensureKeyUnlocked(context);

    if (!unlocked) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _ImportKeyDialog(),
    );

    if (result == null || result.isEmpty) return;

    try {
      await provider.importKeyPair(result);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('私钥导入成功')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败：$e')));
      }
    }
  }

  Future<void> _handleKeyAction(
    BuildContext context,
    KeyProvider provider,
    KeyPair keyPair,
    String action,
  ) async {
    final authProvider = context.read<AuthProvider>();

    switch (action) {
      case 'rename':
        final newName = await showDialog<String>(
          context: context,
          builder: (context) =>
              _RenameKeyDialog(currentName: keyPair.displayName),
        );
        if (newName != null && newName.isNotEmpty && context.mounted) {
          await provider.renameKeyPair(keyPair.id, newName);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('密钥已重命名')));
        }
        break;
      case 'set_default':
        provider.setDefaultKeyPair(keyPair.id);
        break;
      case 'show_qr':
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) =>
                QrDisplayDialog(publicKeyPem: keyPair.publicKeyPem),
          );
        }
        break;
      case 'export_public':
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => _ExportKeyDialog(
              title: '导出公钥',
              keyContent: keyPair.publicKeyPem,
              isPrivateKey: false,
            ),
          );
        }
        break;
      case 'export_private':
        final unlocked = await authProvider.ensureKeyUnlocked(context);
        if (!unlocked) return;

        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('警告'),
              ],
            ),
            content: const Text('私钥非常重要，请勿泄露给他人！\n确定要导出私钥吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('导出'),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          showDialog(
            context: context,
            builder: (context) => _ExportKeyDialog(
              title: '导出私钥',
              keyContent: keyPair.privateKeyPem ?? '',
              isPrivateKey: true,
            ),
          );
        }
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除密钥'),
            content: const Text('确定要删除此密钥对吗？此操作不可恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          try {
            await provider.deleteKeyPair(keyPair.id);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('密钥已删除')));
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
            }
          }
        }
        break;
    }
  }
}

class _ImportKeyDialog extends StatefulWidget {
  @override
  State<_ImportKeyDialog> createState() => _ImportKeyDialogState();
}

class _ImportKeyDialogState extends State<_ImportKeyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.file_download, color: Colors.blue),
          SizedBox(width: 8),
          Text('导入私钥'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('粘贴 RSA 私钥（PEM 格式）：'),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText:
                    '-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----',
                border: OutlineInputBorder(),
              ),
              maxLines: 10,
              minLines: 5,
            ),
            const SizedBox(height: 12),
            Text(
              '提示：私钥格式应包含完整的 PEM 头尾标记',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().isEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('请输入私钥')));
              return;
            }
            final hasPkcs1 = _controller.text.contains(
              '-----BEGIN RSA PRIVATE KEY-----',
            );
            final hasPkcs8 = _controller.text.contains(
              '-----BEGIN PRIVATE KEY-----',
            );
            if (!hasPkcs1 && !hasPkcs8) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('私钥格式不正确，需要 PEM 格式')),
              );
              return;
            }
            Navigator.pop(context, _controller.text.trim());
          },
          child: const Text('导入'),
        ),
      ],
    );
  }
}

class _RenameKeyDialog extends StatefulWidget {
  final String currentName;

  const _RenameKeyDialog({required this.currentName});

  @override
  State<_RenameKeyDialog> createState() => _RenameKeyDialogState();
}

class _RenameKeyDialogState extends State<_RenameKeyDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.currentName;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('重命名密钥'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: '密钥名称',
          hintText: '例如：工作密钥、个人密钥',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        maxLength: 20,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('请输入名称')));
              return;
            }
            Navigator.pop(context, name);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _ExportKeyDialog extends StatelessWidget {
  final String title;
  final String keyContent;
  final bool isPrivateKey;

  const _ExportKeyDialog({
    required this.title,
    required this.keyContent,
    required this.isPrivateKey,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isPrivateKey ? Icons.vpn_key : Icons.key,
            color: isPrivateKey ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPrivateKey)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '私钥非常重要，请勿泄露！',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            const Text('点击下方文本可选中，然后复制：'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                keyContent,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: keyContent));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${isPrivateKey ? '私钥' : '公钥'}已复制到剪贴板')),
              );
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('复制'),
        ),
      ],
    );
  }
}
