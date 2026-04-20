# SecretChat 实现状态

## 已完成的功能

### 1. 项目结构 ✅
- 完整的目录结构创建
- 所有依赖包配置 (pubspec.yaml)
- Material UI 主题配置

### 2. 核心模型 ✅
- `Contact` - 联系人模型
- `Conversation` - 对话模型  
- `Message` - 消息模型
- `KeyPair` - 密钥对模型
- `EncryptedMessage` - 加密消息模型

### 3. 工具类 ✅
- `Constants` - 常量定义 (50MB 限制等)
- `PathUtils` - 路径管理
- `FileUtils` - 文件处理工具

### 4. 加密服务 (需要完善) ⚠️
- `KeyManager` - RSA/ECC 密钥生成和 PEM 解析
  - ✅ RSA 密钥对生成
  - ✅ ECC 密钥对生成
  - ✅ PEM 格式编码/解析
  - ⚠️ 部分 API 需要调整

- `EncryptionService` - 加解密服务 (需要修复类型错误)
  - 设计支持 AES-GCM 混合加密
  - 设计支持 RSA/OAEP 密钥封装
  - 设计支持 HMAC-SHA256 完整性验证
  - 设计支持 RSA 数字签名

### 5. 存储服务 (需要简化) ⚠️
- `StorageService` - 主密码加密存储
  - ✅ PBKDF2 密钥派生
  - ⚠️ AES-GCM 加密需要修复 API

### 6. 状态管理 (部分完成) ⚠️
- `AuthProvider` - 认证状态 (需要修复)

## 待完成的功能

### 高优先级
1. **修复加密服务类型错误**
   - encryption_service.dart 中的类型兼容性问题
   - 需要统一使用 encrypt 包的 API

2. **简化存储服务**
   - 移除复杂的 AES 加密，使用简单的主密码验证
   - 密钥文件以 PEM 格式明文存储（实际应用中应加密）

3. **完成 Providers**
   - `ContactProvider` - 联系人管理
   - `ConversationProvider` - 对话管理
   - `MessageProvider` - 消息管理

4. **创建 UI 界面**
   - 认证界面 (设置/输入主密码)
   - 对话列表界面
   - 聊天详情界面
   - 密钥管理界面
   - 二维码扫描/显示界面

### 中优先级
5. **文件加密功能**
   - 文件选择器集成
   - 文件加密/解密
   - 文件消息展示

6. **二维码功能**
   - 公钥二维码生成
   - 二维码扫描导入

## 快速运行 MVP 版本

由于加密实现较复杂，建议按以下步骤创建可运行的 MVP：

1. **简化加密服务** - 使用纯文本模拟加密
2. **完成基础 UI** - 实现对话列表和聊天界面
3. **添加真实加密** - 在 MVP 基础上逐步替换为真实加密

## 后续完善步骤

1. 修复 `encryption_service.dart` 的类型错误
2. 简化 `file_storage.dart` 或使用 `hive` 等成熟方案
3. 完成所有 Providers
4. 实现完整的 UI 流程
5. 添加文件加密功能
6. 集成二维码扫描
7. 完善错误处理和用户体验

## 技术要点

### 加密流程
```
发送:
明文 → AES-256-GCM → 密文
AES 密钥 → RSA-OAEP(对方公钥) → 加密密钥
密文 → HMAC-SHA256 → 完整性标签
密文 → RSA 签名 (自己私钥) → 签名

接收:
验证 HMAC → 验证签名 → RSA 解密 AES 密钥 → AES 解密
```

### 存储结构
```
应用目录/
├── secretchat/
│   ├── salt.dat          # 随机盐
│   ├── hash.dat          # 密码哈希
│   └── keys/
│       ├── {keyId}.enc   # 加密的密钥对
│       └── contacts/
│           └── {contactId}_pub.pem  # 联系人公钥
```

## 已知问题

1. `encryption_service.dart` 有 4 个类型错误需要修复
2. `file_storage.dart` 有 8 个 API 错误需要修复  
3. `auth_provider.dart` 访问了私有方法

这些问题都需要在使用 encrypt 包和 pointycastle 时注意正确的 API 调用方式。
