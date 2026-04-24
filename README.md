# SecretChat

基于非对称加密的安全聊天应用，支持离线消息传输。

## 功能特性

### 核心功能

- **RSA-2048 加密**
  - 密钥对生成（DER 手动编码、X.509 PEM 格式）
  - PEM 格式密钥导入/导出
  - 密钥重命名

- **混合加密方案**
  - AES-256-GCM 消息加密
  - RSA-OAEP 密钥封装
  - HMAC-SHA256 完整性验证
  - RSA-SHA256 数字签名

- **联系人管理**
  - 多联系人支持
  - 每个联系人可指定不同密钥对
  - 公钥导入（粘贴 PEM 或扫描 QR 码）
  - 联系人编辑/删除

- **消息传输**
  - 加密消息导出（复制到剪贴板）
  - 从剪贴板导入加密消息
  - 消息历史记录本地加密存储
  - 文件加密传输（最大 50MB）

- **QR 码功能**
  - 公钥 QR 码生成
  - 扫描 QR 码导入公钥

- **安全机制**
  - 主密码保护（PBKDF2，100,000 次迭代）
  - 会话内密码验证一次后无需重复验证
  - 手动锁定密钥功能
  - 清空所有数据

### 界面

- Material Design 风格
- 类似微信的双栏布局（联系人列表 + 聊天窗口）
- 密钥管理界面
- 设置界面

## 技术架构

### 加密流程

```
发送消息:
┌─────────┐     ┌──────────────┐     ┌──────────┐
│  明文   │ ──→ │ AES-256-GCM  │ ──→ │  密文    │
└─────────┘     └──────────────┘     └──────────┘
                      │
                      ↓
┌─────────┐     ┌──────────────┐     ┌──────────┐
│AES 密钥 │ ──→ │ RSA-OAEP     │ ──→ │加密密钥  │
│(随机)   │     │ (对方公钥)   │     │          │
└─────────┘     └──────────────┘     └──────────┘

完整性验证:
┌─────────┐     ┌──────────────┐     ┌──────────┐
│  密文   │ ──→ │ HMAC-SHA256  │ ──→ │ HMAC 标签│
└─────────┘     └──────────────┘     └──────────┘

数字签名:
┌─────────┐     ┌──────────────┐     ┌──────────┐
│  密文   │ ──→ │ RSA-SHA256   │ ──→ │  签名    │
│         │     │ (自己私钥)   │     │          │
└─────────┘     └──────────────┘     └──────────┘
```

### 存储结构

```
应用文档目录/
└── secretchat/
    ├── salt.dat                      # PBKDF2 盐
    ├── hash.dat                      # 密码哈希
    ├── keys/
    │   ├── {keyId}.pem              # RSA 私钥（PEM 格式）
    │   └── {keyId}_public.pem       # RSA 公钥（PEM 格式）
    ├── contacts/
    │   └── {contactId}.json         # 联系人配置
    └── messages/
        └── {contactId}_messages.dat # 加密消息历史
```

### 核心依赖

| 包名 | 用途 |
|------|------|
| `pointycastle` | 密码学算法（RSA、AES、HMAC） |
| `encrypt` | 高级加密封装 |
| `crypto` | 哈希算法 |
| `asn1lib` | ASN.1 编解码 |
| `provider` | 状态管理 |
| `qr_flutter` | QR 码生成 |
| `mobile_scanner` | QR 码扫描 |
| `file_picker` | 文件选择 |
| `share_plus` | 内容分享 |
| `path_provider` | 路径管理 |

## 快速开始

### 环境要求

- Flutter SDK >= 3.8.0
- Dart >= 3.8.0
- Java 17 (Android 构建)

### 安装

```bash
flutter pub get
```

### 运行

```bash
flutter run
```

### 构建 APK

```bash
flutter build apk --release
```

APK 输出：`build/app/outputs/flutter-apk/app-release.apk`

## 使用指南

### 首次使用

1. 启动应用，设置主密码（至少 8 位）
2. 系统自动生成 RSA-2048 默认密钥对

### 日常使用

- 打开应用直接进入主界面，无需输入密码
- 仅在使用密钥时验证主密码（会话内验证一次后不再重复）

### 添加联系人

1. 点击主界面右上角 `+` 按钮
2. 输入联系人名称
3. 选择该联系人使用的密钥对（可选，默认使用默认密钥）
4. 粘贴对方公钥 PEM 或扫描 QR 码导入

### 发送加密消息

1. 在联系人列表选择联系人
2. 输入消息文本
3. 点击发送按钮
4. 如需验证主密码，输入后自动加密
5. 加密消息自动复制到剪贴板
6. 通过任意渠道发送给对方

### 接收加密消息

1. 选择对应联系人
2. 点击消息输入框旁的导入按钮
3. 粘贴加密消息（Base64 格式）
4. 系统自动解密并显示明文

### 发送加密文件

1. 在聊天界面点击附件按钮
2. 选择文件（最大 50MB）
3. 系统加密后导出
4. 将加密文件发送给对方

### 密钥管理

1. 进入设置 → 密钥管理
2. 查看所有密钥对
3. 重命名、导出、分享 QR 码
4. 导入新密钥对

### 安全操作

- **锁定密钥**: 设置 → 锁定密钥（需重新验证密码）
- **清空数据**: 设置 → 清空所有数据（不可恢复）

## 项目结构

```
lib/
├── main.dart                          # 应用入口
├── app.dart                            # MaterialApp 配置
├── core/
│   ├── crypto/
│   │   ├── key_manager.dart           # RSA 密钥生成、DER/PEM 编码
│   │   ├── encryption_service.dart    # 加密服务（AES + RSA + HMAC）
│   │   └── models/
│   │       ├── key_pair.dart          # 密钥对模型
│   │       └── encrypted_message.dart # 加密消息模型
│   ├── storage/
│   │   ├── file_storage.dart          # 文件存储、PBKDF2
│   │   └── message_storage.dart       # 消息历史存储
│   └── utils/
│       ├── constants.dart             # 常量定义
│       ├── path_utils.dart            # 跨平台路径处理
│       └── file_utils.dart            # 文件工具
├── models/
│   ├── contact.dart                   # 联系人模型
│   ├── conversation.dart              # 对话模型
│   └── message.dart                   # 消息模型
├── providers/
│   ├── auth_provider.dart             # 认证状态
│   ├── key_provider.dart              # 密钥状态
│   └── contact_provider.dart          # 联系人状态
├── screens/
│   ├── auth/
│   │   └── password_setup_screen.dart # 密码设置界面
│   ├── home/
│   │   ├── home_screen.dart           # 主界面
│   │   └── chat_list_screen.dart      # 联系人列表
│   ├── chat/
│   │   └── chat_detail_screen.dart    # 聊天界面
│   └── settings/
│       ├── settings_screen.dart       # 设置界面
│       └── key_management_screen.dart # 密钥管理
├── widgets/
│   ├── add_contact_dialog.dart        # 添加联系人对话框
│   ├── qr_display_dialog.dart         # QR 码显示
│   └── qr_scanner_dialog.dart         # QR 码扫描
└── theme/
    └── app_theme.dart                 # 主题配置
```

## 安全性说明

### 已实现

- ✅ PBKDF2 密钥派生（100,000 次迭代）
- ✅ 会话内单次密码验证
- ✅ 双重完整性验证（HMAC + 数字签名）
- ✅ 内存中密钥隔离
- ✅ 手动锁定机制
- ✅ 跨平台路径安全处理

## 开发计划

### 待实现

- [x] 私钥文件加密存储
- [x] ECC 加密支持

## 技术细节

### RSA 密钥格式

- **私钥**: PKCS#8 格式 PEM（`-----BEGIN PRIVATE KEY-----`）
- **公钥**: X.509 SubjectPublicKeyInfo 格式 PEM（`-----BEGIN PUBLIC KEY-----`）

### 消息格式

```json
{
  "encryptedKey": "Base64(RSA-OAEP(AES密钥))",
  "encryptedData": "Base64(AES-GCM(明文))",
  "iv": "Base64(AES-GCM IV)",
  "hmac": "Base64(HMAC-SHA256(密文))",
  "signature": "Base64(RSA-SHA256签名)"
}
```

### 跨平台兼容性

使用 `path` 包处理路径分隔符，确保在 Windows、Linux、macOS 上正确运行。

## 许可证

GPLv3

## 免责声明

本项目仅供学习研究使用，请勿用于非法用途。作者不对使用本软件造成的任何损失负责。