import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/contact_provider.dart';
import '../../providers/key_provider.dart';
import 'qr_scanner_dialog.dart';

class AddContactDialog extends StatefulWidget {
  const AddContactDialog({super.key});

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _publicKeyController = TextEditingController();
  bool _isImportingFromQr = false;
  String? _selectedKeyId;

  @override
  void dispose() {
    _nameController.dispose();
    _publicKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleAddContact() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await context.read<ContactProvider>().addContact(
        _nameController.text.trim(),
        _publicKeyController.text.trim(),
        privateKeyId: _selectedKeyId,
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('联系人添加成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyProvider = context.read<KeyProvider>();
    final keyPairs = keyProvider.keyPairs;
    final defaultKeyId = keyProvider.defaultKeyPair?.id;

    return AlertDialog(
      title: const Text('添加联系人'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '联系人名称',
                  hintText: '例如：Alice',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入联系人名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _publicKeyController,
                decoration: InputDecoration(
                  labelText: '公钥 (PEM 格式)',
                  hintText: '-----BEGIN PUBLIC KEY-----...',
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste),
                    onPressed: () => _pasteFromClipboard(),
                    tooltip: '从剪贴板粘贴',
                  ),
                ),
                maxLines: 5,
                minLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入公钥';
                  }
                  if (!value.contains('-----BEGIN PUBLIC KEY-----')) {
                    return '公钥格式不正确，应以 -----BEGIN PUBLIC KEY----- 开头';
                  }
                  return null;
                },
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
                      if (result != null && mounted) {
                        _publicKeyController.text = result;
                      }
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('扫码'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (keyPairs.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedKeyId ?? defaultKeyId,
                  decoration: const InputDecoration(
                    labelText: '使用的密钥对',
                    prefixIcon: Icon(Icons.vpn_key),
                    helperText: '选择用于此会话的本地密钥对',
                  ),
                  items: keyPairs.map((kp) {
                    final isDefault = kp.id == defaultKeyId;
                    return DropdownMenuItem(
                      value: kp.id,
                      child: Text(
                        '${kp.displayName}${isDefault ? ' (默认)' : ''}',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    _selectedKeyId = value;
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(onPressed: _handleAddContact, child: const Text('添加')),
      ],
    );
  }

  Future<void> _pasteFromClipboard() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请手动粘贴公钥到输入框')));
  }
}
