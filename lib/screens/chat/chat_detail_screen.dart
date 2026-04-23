import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../models/contact.dart';
import '../../providers/key_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/crypto/encryption_service.dart';
import '../../core/crypto/models/encrypted_message.dart';
import '../../core/storage/message_storage.dart';
import '../../core/utils/constants.dart';
import '../../core/crypto/models/key_pair.dart';

class ChatDetailScreen extends StatefulWidget {
  final Contact contact;

  const ChatDetailScreen({super.key, required this.contact});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _encryptionService = EncryptionService();
  final _messageStorage = MessageStorageService();
  final List<_MessageItem> _messages = [];
  bool _isLoading = false;
  bool _isDecryptingHistory = false;
  bool _hasHistoryMessages = false;
  bool _needsUnlock = false;
  KeyPair? _contactKeyPair;

  KeyPair? _getKeyPairForContact(KeyProvider keyProvider) {
    if (widget.contact.privateKeyId != null) {
      return keyProvider.getKeyPair(widget.contact.privateKeyId!);
    }
    return keyProvider.defaultKeyPair;
  }

  String? _getKeyPairName() {
    final keyProvider = context.read<KeyProvider>();
    final kp = _getKeyPairForContact(keyProvider);
    if (kp == null) return null;

    final isDefault = kp.id == keyProvider.defaultKeyPair?.id;
    return '${kp.displayName}${isDefault ? '' : ' (指定)'}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkHistoryMessages();
    });
  }

  Future<void> _checkHistoryMessages() async {
    final authProvider = context.read<AuthProvider>();

    if (!authProvider.isKeyUnlocked) {
      final unlocked = await authProvider.ensureKeyUnlocked(context);
      if (!unlocked) {
        setState(() {
          _hasHistoryMessages = false;
          _needsUnlock = false;
        });
        return;
      }
    }

    final key = authProvider.storageService.derivedKey;

    if (key == null) {
      setState(() {
        _hasHistoryMessages = false;
        _needsUnlock = false;
      });
      return;
    }

    final keyProvider = context.read<KeyProvider>();
    if (keyProvider.keyPairs.isEmpty) {
      await keyProvider.loadKeyPairs();
    }

    final encryptedMessages = await _messageStorage.loadMessages(
      widget.contact.id,
      key,
    );

    if (encryptedMessages.isEmpty) {
      setState(() {
        _hasHistoryMessages = false;
        _needsUnlock = false;
      });
      return;
    }

    final keyPair = _getKeyPairForContact(keyProvider);
    if (keyPair != null && keyPair.privateKeyPem != null) {
      setState(() {
        _hasHistoryMessages = true;
        _needsUnlock = false;
      });
      await _loadHistoryMessages();
    } else {
      setState(() {
        _hasHistoryMessages = true;
        _needsUnlock = true;
      });
    }
  }

  Future<void> _unlockAndLoadHistory() async {
    final authProvider = context.read<AuthProvider>();
    final unlocked = await authProvider.ensureKeyUnlocked(context);

    if (!unlocked) return;

    final keyProvider = context.read<KeyProvider>();
    await keyProvider.loadKeyPairs();

    setState(() {
      _needsUnlock = false;
    });

    await _loadHistoryMessages();
  }

  Future<void> _loadHistoryMessages() async {
    setState(() => _isDecryptingHistory = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final key = authProvider.storageService.derivedKey;

      if (key == null) {
        setState(() => _isDecryptingHistory = false);
        return;
      }

      final encryptedMessages = await _messageStorage.loadMessages(
        widget.contact.id,
        key,
      );

      if (encryptedMessages.isEmpty) {
        setState(() {
          _isDecryptingHistory = false;
          _hasHistoryMessages = false;
        });
        return;
      }

      final keyProvider = context.read<KeyProvider>();
      final keyPair = _getKeyPairForContact(keyProvider);

      if (keyPair == null || keyPair.privateKeyPem == null) {
        setState(() {
          _isDecryptingHistory = false;
          _messages.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('密钥未准备好，请返回后重试')));
        }
        return;
      }

      for (final msg in encryptedMessages) {
        try {
          final isSent = msg.metadata.messageId.startsWith('sent_');

          final privateKeyPem = keyPair.privateKeyPem!;
          final senderPublicKeyPem = isSent
              ? keyPair.publicKeyPem
              : widget.contact.publicKeyPem ?? '';

          final decrypted = await _encryptionService.decryptText(
            msg,
            privateKeyPem,
            senderPublicKeyPem,
          );

          setState(() {
            _messages.add(
              _MessageItem(
                content: decrypted,
                storedMessage: msg,
                isSent: isSent,
                type: msg.metadata.type,
                verified: true,
                signatureVerified:
                    senderPublicKeyPem.isNotEmpty && msg.signature != null,
                fileName: msg.metadata.fileName,
              ),
            );
          });
        } catch (e) {
          final msgId = msg.metadata.messageId;
          setState(() {
            _messages.add(
              _MessageItem(
                storedMessage: msg,
                isSent: msgId.startsWith('sent_'),
                type: msg.metadata.type,
                verified: false,
                signatureVerified: false,
                fileName: msg.metadata.fileName,
                decryptError: '解密失败',
              ),
            );
          });
        }
      }
    } finally {
      setState(() => _isDecryptingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyPairName = _getKeyPairName();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.contact.name),
            Row(
              children: [
                Text(
                  _hasPublicKey() ? '✓ 已配置公钥' : '⚠ 未配置公钥',
                  style: TextStyle(
                    fontSize: 12,
                    color: _hasPublicKey()
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                  ),
                ),
                if (keyPairName != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.vpn_key, size: 12, color: Colors.blue.shade300),
                  const SizedBox(width: 4),
                  Text(
                    keyPairName,
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade300),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isDecryptingHistory) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('正在解密历史消息...', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    if (_needsUnlock && _hasHistoryMessages) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.blue.shade400),
            const SizedBox(height: 16),
            Text(
              '有历史消息待解密',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮输入密码解锁查看',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _unlockAndLoadHistory,
              icon: const Icon(Icons.lock_open),
              label: const Text('解锁查看历史消息'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text('暂无消息', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(
              '发送消息后可导出加密文本\n通过其他应用发送给对方',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(_MessageItem message) {
    final hasError = message.decryptError != null;

    return Align(
      alignment: message.isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: hasError
              ? Colors.red.shade50
              : message.isSent
              ? Colors.blue.shade100
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasError)
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          message.decryptError!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  if (!hasError && message.type == MessageType.text)
                    Text(
                      message.content ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),
                  if (!hasError &&
                      (message.type == MessageType.file ||
                          message.type == MessageType.image))
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          message.type == MessageType.image
                              ? Icons.image
                              : Icons.insert_drive_file,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(message.fileName ?? '文件'),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!message.isSent && message.signatureVerified)
                        Icon(
                          Icons.verified,
                          size: 14,
                          color: Colors.green.shade700,
                        ),
                      if (!message.isSent && !message.signatureVerified)
                        Icon(
                          Icons.warning,
                          size: 14,
                          color: Colors.orange.shade700,
                        ),
                      if (message.verified)
                        Icon(
                          Icons.verified_user,
                          size: 14,
                          color: Colors.green.shade700,
                        ),
                      const SizedBox(width: 4),
                      Text(
                        message.isSent
                            ? '已发送'
                            : message.signatureVerified
                            ? '已验签'
                            : '签名未验证',
                        style: TextStyle(
                          fontSize: 11,
                          color: message.signatureVerified
                              ? Colors.grey.shade600
                              : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (message.encryptedMessage != null ||
                message.storedMessage != null)
              Divider(height: 1, color: Colors.grey.shade300),
            if (message.encryptedMessage != null ||
                message.storedMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      message.isSent ? '密文已保存' : '密文已保存',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.encryptedMessage != null)
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () => _copyEncryptedMessage(message),
                            tooltip: '复制传输密文',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.share, size: 18),
                          onPressed: () => _showEncryptedMessage(message),
                          tooltip: '查看密文',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: '输入消息...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _hasPublicKey() && !_isLoading ? _pickFile : null,
              tooltip: '加密文件',
            ),
            IconButton(
              icon: const Icon(Icons.content_paste),
              onPressed: _importFromClipboard,
              tooltip: '从剪贴板导入',
            ),
            IconButton(
              icon: const Icon(Icons.file_present),
              onPressed: () => _showImportDialog(),
              tooltip: '手动粘贴导入',
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _hasPublicKey() && !_isLoading ? _sendMessage : null,
              tooltip: '发送消息',
            ),
          ],
        ),
      ),
    );
  }

  bool _hasPublicKey() {
    return widget.contact.publicKeyPem != null &&
        widget.contact.publicKeyPem!.isNotEmpty;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final keyProvider = context.read<KeyProvider>();
    final keyPair = _getKeyPairForContact(keyProvider);

    if (keyPair == null) {
      _showError('请先在设置中生成密钥对');
      return;
    }

    if (keyPair.privateKeyPem == null) {
      _showError('密钥对缺少私钥');
      return;
    }

    if (widget.contact.publicKeyPem == null ||
        widget.contact.publicKeyPem!.isEmpty) {
      _showError('联系人未配置公钥');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final unlocked = await authProvider.ensureKeyUnlocked(context);
    if (!unlocked) return;

    try {
      setState(() => _isLoading = true);

      final transportMessage = await _encryptionService.encryptText(
        text,
        widget.contact.publicKeyPem!,
        keyPair.privateKeyPem!,
      );

      final storageMessage = await _encryptionService.encryptForStorage(
        text,
        keyPair.publicKeyPem,
        keyPair.privateKeyPem!,
      );

      final savedMessage = EncryptedMessage(
        encryptedContent: storageMessage.encryptedContent,
        encryptedAesKey: storageMessage.encryptedAesKey,
        signature: storageMessage.signature,
        hmac: storageMessage.hmac,
        metadata: MessageMetadata(
          messageId: 'sent_${storageMessage.metadata.messageId}',
          type: storageMessage.metadata.type,
          fileName: storageMessage.metadata.fileName,
          fileSize: storageMessage.metadata.fileSize,
          timestamp: storageMessage.metadata.timestamp,
        ),
      );

      final encryptionKey = authProvider.storageService.derivedKey;
      if (encryptionKey != null) {
        await _messageStorage.saveMessage(
          widget.contact.id,
          savedMessage,
          encryptionKey,
        );
      }

      setState(() {
        _messages.add(
          _MessageItem(
            content: text,
            encryptedMessage: transportMessage,
            storedMessage: savedMessage,
            isSent: true,
            type: MessageType.text,
            verified: true,
          ),
        );
        _messageController.clear();
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('消息已加密并保存，点击复制图标导出密文'),
              action: SnackBarAction(
                label: '复制',
                onPressed: () => _copyEncryptedMessage(_messages.last),
              ),
            ),
          );
        }
      });
    } catch (e) {
      _showError('加密失败：$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.size > Constants.maxFileSize) {
      _showError('文件过大，最大支持 ${Constants.maxFileSize ~/ 1024 ~/ 1024}MB');
      return;
    }

    final keyProvider = context.read<KeyProvider>();
    if (keyProvider.defaultKeyPair == null ||
        keyProvider.defaultKeyPair!.privateKeyPem == null) {
      _showError('请先配置密钥对');
      return;
    }

    if (widget.contact.publicKeyPem == null ||
        widget.contact.publicKeyPem!.isEmpty) {
      _showError('联系人未配置公钥');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final unlocked = await authProvider.ensureKeyUnlocked(context);
    if (!unlocked) return;

    try {
      setState(() => _isLoading = true);

      final fileData = Uint8List.fromList(file.bytes!);
      final encryptedMessage = await _encryptionService.encryptFile(
        fileData,
        file.name,
        file.extension ?? '',
        widget.contact.publicKeyPem!,
        keyProvider.defaultKeyPair!.privateKeyPem!,
      );

      setState(() {
        _messages.add(
          _MessageItem(
            encryptedMessage: encryptedMessage,
            isSent: true,
            type: file.extension?.startsWith('image') == true
                ? MessageType.image
                : MessageType.file,
            verified: true,
            fileName: file.name,
          ),
        );
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${file.name} 已加密'),
              action: SnackBarAction(
                label: '复制密文',
                onPressed: () => _copyEncryptedMessage(_messages.last),
              ),
            ),
          );
        }
      });
    } catch (e) {
      _showError('文件加密失败：$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _copyEncryptedMessage(_MessageItem message) async {
    if (message.encryptedMessage == null) return;

    try {
      final encoded = message.encryptedMessage!.encode();
      await Clipboard.setData(ClipboardData(text: encoded));

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密文已复制到剪贴板')));
    } catch (e) {
      _showError('复制失败：$e');
    }
  }

  Future<void> _showEncryptedMessage(_MessageItem message) async {
    if (message.encryptedMessage == null) return;

    final encoded = message.encryptedMessage!.encode();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('加密消息'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('以下为加密后的密文：'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  encoded,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '使用说明：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('1. 复制上方密文'),
              const Text('2. 通过微信/邮件等发送给对方'),
              const Text('3. 对方导入密文即可解密'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          ElevatedButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: encoded));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
              }
            },
            child: const Text('复制'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _ImportMessageDialog(),
    );

    if (result != null) {
      await _processImportedMessage(result);
    }
  }

  Future<void> _importFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text;

      if (text == null || text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('剪贴板中没有文本内容')),
        );
        return;
      }

      final trimmedText = text.trim();
      
      if (!trimmedText.startsWith('eyJ') && !trimmedText.contains('encryptedContent')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('剪贴板内容不是有效的加密消息格式')),
        );
        return;
      }

      await _processImportedMessage(trimmedText);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  Future<void> _processImportedMessage(String encodedMessage) async {
    final authProvider = context.read<AuthProvider>();
    final unlocked = await authProvider.ensureKeyUnlocked(context);
    if (!unlocked) return;

    try {
      final message = EncryptedMessage.decode(encodedMessage);
      final keyProvider = context.read<KeyProvider>();
      final keyPair = _getKeyPairForContact(keyProvider);

      if (keyPair == null || keyPair.privateKeyPem == null) {
        _showError('请先配置密钥对');
        return;
      }

      final encryptionKey = authProvider.storageService.derivedKey;
      if (encryptionKey != null) {
        await _messageStorage.saveMessage(widget.contact.id, message, encryptionKey);
      }

      final decrypted = await _encryptionService.decryptText(
        message,
        keyPair.privateKeyPem!,
        widget.contact.publicKeyPem ?? '',
      );

      setState(() {
        _messages.add(
          _MessageItem(
            content: decrypted,
            encryptedMessage: message,
            isSent: false,
            type: message.metadata.type,
            verified: true,
            signatureVerified:
                widget.contact.publicKeyPem != null &&
                widget.contact.publicKeyPem!.isNotEmpty &&
                message.signature != null,
            fileName: message.metadata.fileName,
          ),
        );
      });

      if (context.mounted) {
        final hasPublicKey =
            widget.contact.publicKeyPem != null &&
            widget.contact.publicKeyPem!.isNotEmpty;
        final hasSignature = message.signature != null;

        if (hasPublicKey && hasSignature) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('消息已解密并验签 ✓'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (!hasPublicKey) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('消息已解密并保存（未验签 - 请添加联系人公钥）'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('消息已解密并保存')));
        }
      }
    } catch (e) {
      if (e.toString().contains('签名验证失败')) {
        _showError('⚠️ 签名验证失败 - 消息可能被篡改或发送方身份不匹配');
      } else if (e.toString().contains('HMAC验证失败')) {
        _showError('⚠️ 消息完整性验证失败');
      } else {
        _showError('解密失败：$e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使用说明'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('发送消息：', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('1. 输入消息内容'),
            Text('2. 点击发送按钮'),
            Text('3. 消息自动加密'),
            Text('4. 点击复制图标导出密文'),
            Text('5. 通过其他应用发送密文'),
            SizedBox(height: 16),
            Text('接收消息：', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('1. 收到对方发来的密文'),
            Text('2. 点击导入按钮'),
            Text('3. 粘贴密文并导入'),
            Text('4. 自动解密并显示'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

class _MessageItem {
  final String? content;
  final EncryptedMessage? encryptedMessage; // 传输密文（用于导出）
  final EncryptedMessage? storedMessage; // 存储密文（用于历史解密）
  final bool isSent;
  final MessageType type;
  final bool verified;
  final bool signatureVerified;
  final String? fileName;
  final String? decryptError;

  _MessageItem({
    this.content,
    this.encryptedMessage,
    this.storedMessage,
    required this.isSent,
    required this.type,
    required this.verified,
    this.signatureVerified = true,
    this.fileName,
    this.decryptError,
  });
}

class _ImportMessageDialog extends StatefulWidget {
  @override
  State<_ImportMessageDialog> createState() => _ImportMessageDialogState();
}

class _ImportMessageDialogState extends State<_ImportMessageDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导入加密消息'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('粘贴对方发送的密文：'),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: '粘贴密文...',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              Navigator.pop(context, _controller.text);
            }
          },
          child: const Text('导入'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
