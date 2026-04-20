import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/storage/file_storage.dart';

class AuthProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  bool _hasSetup = false;
  bool _isLoading = false;
  bool _isKeyUnlocked = false; // 密钥是否已解锁（本次会话）

  bool get hasSetup => _hasSetup;
  bool get isLoading => _isLoading;
  bool get isKeyUnlocked => _isKeyUnlocked; // 是否已验证过密码

  /// 检查是否已设置过主密码（启动时调用）
  Future<void> checkSetup() async {
    _isLoading = true;
    notifyListeners();

    try {
      final salt = await _storageService.readSalt();
      _hasSetup = salt != null;
      // 不需要输入密码，直接进入主界面
      _isKeyUnlocked = false; // 密钥未解锁，需要操作时验证
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 首次设置主密码
  Future<void> setup(String password) async {
    _isLoading = true;
    notifyListeners();

    await _storageService.initializeStorage(password);
    _hasSetup = true;
    _isKeyUnlocked = true; // 设置密码后自动解锁

    _isLoading = false;
    notifyListeners();
  }

  /// 验证密码并解锁密钥（密钥操作前调用）
  /// 返回 true 表示验证成功，false 表示失败
  Future<bool> verifyAndUnlock(String password) async {
    try {
      final valid = await _storageService.verifyPassword(password);
      if (valid) {
        await _storageService.unlock(password);
        _isKeyUnlocked = true; // 标记为已解锁
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 检查密钥是否已解锁，未解锁则弹出密码验证对话框
  /// 返回 true 表示已解锁或验证成功，false 表示验证失败或取消
  Future<bool> ensureKeyUnlocked(BuildContext context) async {
    if (_isKeyUnlocked) {
      return true; // 已解锁，无需再次验证
    }

    // 未解锁，弹出密码验证对话框
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => const _PasswordVerifyDialog(),
    );

    return verified == true;
  }

  /// 手动锁定密钥（从设置界面调用）
  void lockKeys() {
    _storageService.lock();
    _isKeyUnlocked = false;
    notifyListeners();
  }
}

/// 内部密码验证对话框
class _PasswordVerifyDialog extends StatefulWidget {
  const _PasswordVerifyDialog();

  @override
  State<_PasswordVerifyDialog> createState() => _PasswordVerifyDialogState();
}

class _PasswordVerifyDialogState extends State<_PasswordVerifyDialog> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyAndUnlock(
      _passwordController.text,
    );

    if (success) {
      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      setState(() {
        _error = '密码错误';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.blue),
          SizedBox(width: 8),
          Text('验证主密码'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('请输入主密码以使用密钥功能'),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofocus: true,
            onSubmitted: (_) => _handleVerify(),
            decoration: InputDecoration(
              labelText: '主密码',
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleVerify,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('确定'),
        ),
      ],
    );
  }
}
