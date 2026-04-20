import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/key_provider.dart';
import 'theme/app_theme.dart';
import 'screens/auth/password_setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/settings/settings_screen.dart';

void main() {
  runApp(const SecretChatApp());
}

class SecretChatApp extends StatelessWidget {
  const SecretChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
        ChangeNotifierProvider(create: (_) => KeyProvider()),
      ],
      child: MaterialApp(
        title: 'SecretChat',
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // 启动时检查是否已设置密码
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkSetup();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // 正在检查设置状态
    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在初始化...'),
            ],
          ),
        ),
      );
    }

    // 未设置密码 → 显示设置密码界面
    if (!authProvider.hasSetup) {
      return const PasswordSetupScreen();
    }

    // 已设置密码 → 直接进入主界面（密钥未解锁，需要操作时验证）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactProvider>().loadContacts();
      context.read<KeyProvider>().loadKeyPairs();
    });

    return const HomeScreen();
  }
}
