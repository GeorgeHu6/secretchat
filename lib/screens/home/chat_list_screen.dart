import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/contact_provider.dart';
import '../../providers/key_provider.dart';
import '../../models/contact.dart';
import '../chat/chat_detail_screen.dart';
import '../../widgets/add_contact_dialog.dart';
import '../../widgets/qr_scanner_dialog.dart';
import '../../core/storage/message_storage.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ContactProvider>(
      builder: (context, contactProvider, child) {
        final contacts = contactProvider.contacts;

        if (contacts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无对话',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  '点击右上角 + 添加联系人',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            final contact = contacts[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    contact.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  contact.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  contact.publicKeyPem != null ? '已配置公钥' : '未配置公钥',
                  style: TextStyle(
                    color: contact.publicKeyPem != null
                        ? Colors.green.shade600
                        : Colors.orange.shade600,
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => _handleContactAction(
                    context,
                    contactProvider,
                    contact,
                    value,
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit_key',
                      child: Row(
                        children: [
                          Icon(Icons.key, size: 20),
                          SizedBox(width: 8),
                          Text('修改公钥'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除联系人', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailScreen(contact: contact),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleContactAction(
    BuildContext context,
    ContactProvider provider,
    Contact contact,
    String action,
  ) async {
    switch (action) {
      case 'edit_key':
        await showDialog(
          context: context,
          builder: (context) => _EditPublicKeyDialog(contact: contact),
        );
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除联系人'),
            content: Text('确定要删除联系人 "${contact.name}" 吗？\n所有消息记录也将被删除。'),
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
        if (confirmed == true && context.mounted) {
          await provider.deleteContact(contact.id);
          await MessageStorageService().deleteMessages(contact.id);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('已删除联系人 ${contact.name}')));
        }
        break;
    }
  }
}

class _EditPublicKeyDialog extends StatefulWidget {
  final Contact contact;

  const _EditPublicKeyDialog({required this.contact});

  @override
  State<_EditPublicKeyDialog> createState() => _EditPublicKeyDialogState();
}

class _EditPublicKeyDialogState extends State<_EditPublicKeyDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _selectedKeyId;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.contact.publicKeyPem ?? '';
    _selectedKeyId = widget.contact.privateKeyId;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    if (_controller.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入公钥')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<ContactProvider>();
      final updatedContact = widget.contact.copyWith(
        publicKeyPem: _controller.text.trim(),
        privateKeyId: _selectedKeyId,
      );
      await provider.updateContact(updatedContact);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('联系人信息已更新')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失败：$e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyProvider = context.read<KeyProvider>();
    final keyPairs = keyProvider.keyPairs;
    final defaultKeyId = keyProvider.defaultKeyPair?.id;

    return AlertDialog(
      title: Text('编辑联系人 - ${widget.contact.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('公钥', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: '公钥 (PEM 格式)',
                hintText: '-----BEGIN PUBLIC KEY-----...',
                border: OutlineInputBorder(),
              ),
              maxLines: 8,
              minLines: 5,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final result = await showDialog<String>(
                      context: context,
                      builder: (context) => const QrScannerDialog(),
                    );
                    if (result != null) {
                      _controller.text = result;
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('扫码导入'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('密钥对', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (keyPairs.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedKeyId ?? defaultKeyId,
                decoration: const InputDecoration(
                  labelText: '使用的密钥对',
                  border: OutlineInputBorder(),
                  helperText: '选择用于此会话的本地密钥对',
                ),
                items: keyPairs.map((kp) {
                  final isDefault = kp.id == defaultKeyId;
                  return DropdownMenuItem(
                    value: kp.id,
                    child: Text('${kp.displayName}${isDefault ? ' (默认)' : ''}'),
                  );
                }).toList(),
                onChanged: (value) {
                  _selectedKeyId = value;
                },
              )
            else
              const Text(
                '请先在密钥管理中生成密钥对',
                style: TextStyle(color: Colors.orange),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveKey,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}
