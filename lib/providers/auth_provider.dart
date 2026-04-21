import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/storage/file_storage.dart';

class AuthProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  bool _hasSetup = false;
  bool _isLoading = false;
  bool _isKeyUnlocked = false;

  bool get hasSetup => _hasSetup;
  bool get isLoading => _isLoading;
  bool get isKeyUnlocked => _isKeyUnlocked;

  Future<void> checkSetup() async {
    _isLoading = true;
    notifyListeners();

    try {
      final hasData = await _storageService.hasSetup();
      _hasSetup = hasData;
      _isKeyUnlocked = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setup(String password) async {
    _isLoading = true;
    notifyListeners();

    await _storageService.initializeStorage(password);
    _hasSetup = true;
    _isKeyUnlocked = true;

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> verifyAndUnlock(String password) async {
    try {
      final valid = await _storageService.verifyPassword(password);
      if (valid) {
        await _storageService.unlock(password);
        _isKeyUnlocked = true;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> ensureKeyUnlocked(BuildContext context) async {
    if (_isKeyUnlocked) {
      return true;
    }

    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => const _PasswordVerifyDialog(),
    );

    return verified == true;
  }

  void lockKeys() {
    _storageService.lock();
    _isKeyUnlocked = false;
    notifyListeners();
  }

  Future<void> clearAllData() async {
    await _storageService.clearAllData();
    _hasSetup = false;
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
