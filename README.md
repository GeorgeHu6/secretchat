# SecretChat

基于 Flutter 的离线安全聊天工具，使用非对称加密封装消息，可通过剪贴板、二维码或其他外部渠道传输密文。

## 当前状态

当前仓库已经具备可运行的客户端骨架和主要核心能力：

- 主密码初始化与会话内解锁
- 本地加密存储私钥和消息历史
- RSA / ECC 密钥对生成与导入
- 联系人管理与联系人公钥绑定
- 文本消息加密、导出、导入、解密
- 文件加密导出
- 公钥二维码展示与扫码导入

项目仍然是纯客户端应用，没有内置服务端或实时通信层。消息的“发送”本质上是生成密文，随后由用户通过微信、邮件或其他渠道传递给对方。

## 功能概览

### 已实现

- **主密码与本地安全**
  - 首次启动设置主密码
  - 使用 PBKDF2 派生 32 字节密钥
  - 私钥文件、密钥名称元数据、消息历史均使用 AES-GCM 本地加密
  - 支持手动锁定密钥
  - 支持清空所有本地数据

- **密钥管理**
  - 生成 RSA 密钥对
  - 生成 ECC 密钥对
  - 导入私钥
  - 重命名密钥
  - 设为默认密钥
  - 导出公钥 / 私钥文本
  - 公钥二维码展示

- **联系人管理**
  - 添加联系人
  - 为联系人保存对方公钥
  - 为联系人指定使用的本地密钥对
  - 编辑联系人公钥
  - 删除联系人及对应消息历史
  - 支持扫码导入联系人公钥

- **消息与文件**
  - 文本消息加密
  - 密文复制到剪贴板
  - 从剪贴板导入密文
  - 手动粘贴密文导入
  - 历史消息本地保存并解密展示
  - 文件加密导出
  - 消息验签状态和完整性状态提示

### 当前限制

- 没有内置网络传输能力
- 没有自动生成默认密钥；首次使用后需要在“设置 -> 密钥管理”中手动生成或导入
- 文件消息目前以密文导出为主，接收端文件恢复流程仍偏基础
- `Conversation` 模型已存在，但当前首页仍以联系人列表为主，不是完整的会话系统

## 技术架构

### 目录结构

```text
lib/
├── main.dart
├── app.dart
├── core/
│   ├── crypto/
│   │   ├── data_encryption.dart
│   │   ├── encryption_service.dart
│   │   ├── key_manager.dart
│   │   └── models/
│   │       ├── encrypted_message.dart
│   │       └── key_pair.dart
│   ├── services/
│   │   └── qr_service.dart
│   ├── storage/
│   │   ├── file_storage.dart
│   │   └── message_storage.dart
│   └── utils/
│       ├── constants.dart
│       ├── file_utils.dart
│       └── path_utils.dart
├── models/
│   ├── contact.dart
│   ├── conversation.dart
│   └── message.dart
├── providers/
│   ├── auth_provider.dart
│   ├── contact_provider.dart
│   └── key_provider.dart
├── screens/
│   ├── auth/
│   ├── chat/
│   ├── home/
│   └── settings/
├── theme/
│   └── app_theme.dart
└── widgets/
    ├── add_contact_dialog.dart
    ├── qr_display_dialog.dart
    └── qr_scanner_dialog.dart
```

### 分层说明

- `screens/`：页面级 UI，负责交互和流程编排
- `widgets/`：复用弹窗和小组件
- `providers/`：全局状态管理
- `core/crypto/`：密钥生成、消息加解密、本地数据加密
- `core/storage/`：本地文件读写和消息历史持久化
- `models/`：联系人、消息、会话等业务模型

### 启动流程

1. `main.dart` 启动 `SecretChatApp`
2. `app.dart` 注入 `AuthProvider`、`ContactProvider`、`KeyProvider`
3. `AuthWrapper` 检查本地是否已初始化主密码
4. 未初始化则进入密码设置页，已初始化则进入首页
5. `StorageService` 被注入到密钥和联系人状态中，后续敏感操作通过解锁状态控制

## 加密与存储

### 传输消息

当前消息封装使用混合方案：

- 消息内容使用 AES-GCM 加密
- RSA 联系人使用 RSA 加密会话密钥
- ECC 联系人使用 ECDH/ECIES 风格流程派生会话密钥
- 支持 HMAC 完整性校验
- 支持 RSA / ECDSA 签名与验签

消息对象定义见 `lib/core/crypto/models/encrypted_message.dart`，核心字段包括：

- `encryptedContent`
- `encryptedAesKey`
- `signature`
- `hmac`
- `metadata`

### 本地存储

本地数据路径由 `PathUtils` 管理，实际结构更接近：

```text
应用文档目录/
└── secretchat/
    ├── salt.dat
    ├── hash.dat
    ├── key_names.json
    ├── keys/
    │   ├── {keyId}.pem
    │   └── contacts/
    │       └── {contactId}_pub.pem
    └── messages/
        └── {contactId}/
            └── {messageId}.enc
```

说明：

- `salt.dat`：PBKDF2 盐值
- `hash.dat`：派生结果校验值
- `keys/{keyId}.pem`：加密后的私钥文件
- `keys/contacts/{contactId}_pub.pem`：联系人公钥
- `messages/{contactId}/{messageId}.enc`：加密后的历史消息

## 主要依赖

| 包名 | 用途 |
|------|------|
| `pointycastle` | RSA / ECC / PBKDF2 / AES-GCM 等密码学能力 |
| `encrypt` | 高层加密封装 |
| `crypto` | 哈希与 HMAC |
| `provider` | 状态管理 |
| `path_provider` | 应用数据目录定位 |
| `file_picker` | 文件选择 |
| `qr_flutter` | 公钥二维码展示 |
| `mobile_scanner` | 二维码扫描 |
| `share_plus` | 分享相关能力 |

## 快速开始

### 环境要求

- Flutter SDK `>= 3.8.0`
- Dart SDK `>= 3.8.0`
- Java 17（Android 构建）

### 安装依赖

```bash
flutter pub get
```

### 运行

```bash
flutter run
```

### 构建 Android APK

```bash
flutter build apk --release
```

输出路径：

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 使用说明

### 首次使用

1. 启动应用并设置主密码
2. 进入首页后，打开“设置 -> 密钥管理”
3. 手动生成一把 RSA 或 ECC 密钥，或导入已有私钥
4. 将自己的公钥通过文本或二维码分享给联系人

### 添加联系人

1. 在首页点击 `+`
2. 输入联系人名称
3. 粘贴对方公钥，或通过扫码导入
4. 可选地为该联系人指定本地使用的密钥对

### 发送文本消息

1. 进入联系人聊天页
2. 输入消息内容
3. 点击发送
4. 应用会生成一份用于传输的密文，并保存一份本地可解密历史
5. 点击消息上的复制图标，将密文复制到剪贴板
6. 通过任意外部渠道发送给对方

### 接收文本消息

1. 进入对应联系人聊天页
2. 使用“从剪贴板导入”或“手动粘贴导入”
3. 应用解密后会显示明文并保存历史

### 文件加密

1. 在聊天页点击附件按钮
2. 选择文件
3. 应用将文件内容加密为消息载荷
4. 复制生成的密文并通过外部渠道发送

## 测试

当前仓库包含的测试主要聚焦在密钥生成和存取：

- `test/key_generation_test.dart`
- `test/key_save_load_test.dart`

运行：

```bash
flutter test
```

## 更新日志

以下内容根据当前仓库的 Git 记录整理。

### v1.5.0 - 2026-04-24

- 添加 ECC 加密算法支持
- 增加私钥文件加密存储
- 修复消息分享问题
- 修复 PC 端二维码显示失败问题
- 升级项目依赖
- 补充 Android APK 构建工作流、构建配置和应用图标

相关提交：

- `0d48996` 迭代版本号
- `e06fff5` 添加ECC加密算法，修复消息分享以及PC端二维码显示失败的问题
- `1aacdae` 添加私钥文件加密存储
- `6c125ef` 为apk添加icon
- `fdbd7fd` / `46e04d9` / `f598cc2` / `f489b96` APK 构建流程与配置修复
- `e43d38d` 升级项目依赖
- `a145e67` 修复 ndkversion

### v1.0.0 - 2026-04-21

- 标记首个正式版本
- 在此前基础上完成应用初始化、图标资源、密钥导出优化
- 增加清空数据和从剪贴板导入消息功能
- 增加 Linux AppImage 与 Windows 构建工作流
- 修复 Windows 上密钥对保存问题

相关提交：

- `827c368` 确定正式版
- `7537b2a` 添加清空数据和从剪贴板导入消息的功能
- `35ab9e3` 添加AppImage构建工作流
- `f558529` 添加windows版本构建工作流
- `8f8496f` 修复windows上无法正确保存密钥对的问题
- `eae782b` 优化密钥对导出逻辑
- `574acf6` / `e812412` 添加应用图标
- `e228a56` create application
- `173f0b1` Initial commit

## 许可证

GPLv3

## 免责声明

本项目仅供学习和研究使用，请勿用于非法用途。
