# Google 登录配置指南

## ✅ 已完成的工作

1. ✅ GoogleSignIn SDK 已添加
2. ✅ GoogleAuthManager.swift 已创建
3. ✅ AuthManager 已集成 Google 登录方法
4. ✅ AuthView 已添加 Google 登录按钮
5. ✅ Info.plist 已创建（包含 URL Schemes 配置）
6. ✅ earthlordApp.swift 已添加 URL 回调处理

## 🔧 需要手动配置的步骤

### 步骤 1：获取 Google Client ID

1. 访问 [Google Cloud Console](https://console.cloud.google.com/)
2. 创建新项目或选择现有项目
3. 启用 **Google Sign-In API**
4. 在 "凭据" 页面创建 **OAuth 2.0 客户端 ID**
   - 应用类型：iOS
   - Bundle ID：`com.earthlord.game`（或你的实际 Bundle ID）
   - 记录生成的 Client ID（格式：`123456789-xxx.apps.googleusercontent.com`）

### 步骤 2：配置 GoogleAuthManager.swift

打开文件：`earthlord/earthlord/Managers/GoogleAuthManager.swift`

找到第 14 行左右的代码：
```swift
private var clientID: String {
    // TODO: 替换为你的 Google Client ID
    return "YOUR_GOOGLE_CLIENT_ID"
}
```

替换为你的实际 Client ID：
```swift
private var clientID: String {
    return "123456789-xxx.apps.googleusercontent.com"  // 替换为你的 Client ID
}
```

### 步骤 3：配置 Info.plist

打开文件：`earthlord/earthlord/Info.plist`

找到第 16 行左右的代码：
```xml
<!-- 替换为你的 Reversed Client ID -->
<string>YOUR_REVERSED_CLIENT_ID</string>
```

替换为你的 Reversed Client ID：
```xml
<!-- 例如：com.googleusercontent.apps.123456789-xxx -->
<string>com.googleusercontent.apps.123456789-xxx</string>
```

**重要说明：Reversed Client ID 的格式**
- 原 Client ID: `123456789-abc.apps.googleusercontent.com`
- Reversed Client ID: `com.googleusercontent.apps.123456789-abc`

### 步骤 4：在 Xcode 中配置 Info.plist

由于这是现代 Xcode 项目，需要在 Xcode 中关联 Info.plist：

1. 打开 Xcode 项目
2. 选择 `earthlord` target
3. 进入 `Build Settings` 选项卡
4. 搜索 `Info.plist File`
5. 设置值为：`earthlord/Info.plist`

### 步骤 5：配置 Supabase Google Provider

你已经在 Supabase Dashboard 中启用了 Google Provider，确认以下配置：

1. 访问 [Supabase Dashboard](https://supabase.com/dashboard/project/xlhkojuliphmvmzhpgzw/auth/providers)
2. 在 Google Provider 设置中：
   - ✅ Enabled
   - ✅ **Authorized Client IDs**: 填入你的 Google Client ID（从步骤 1 获取）
   - ✅ **Skip nonce check**: 已开启

## 📱 测试 Google 登录

完成上述配置后：

1. 在 Xcode 中运行项目
2. 进入登录页面
3. 点击 "使用 Google 登录" 按钮
4. 观察控制台日志：

```
🔵 用户点击 Google 登录按钮
   开始 Google 登录流程...
🔵 Google 登录 - 开始流程
   步骤 1: 配置 Google Sign-In
   步骤 2: 获取顶层视图控制器
   步骤 3: 调用 Google Sign-In SDK
   ✅ Google 登录成功
   用户 Email: xxx@gmail.com
   用户名称: XXX
   步骤 4: 获取 Google ID Token
   ✅ ID Token 获取成功: xxx...
   步骤 5: 使用 Google ID Token 登录 Supabase
   ✅ Supabase 登录成功
   Supabase 用户 ID: xxx
   Supabase 用户 Email: xxx@gmail.com
🔵 Google 登录 - 流程完成
✅ Google 登录完成
```

## ⚠️ 常见问题

### 问题 1：点击按钮没有反应
- 检查 Google Client ID 是否正确配置
- 检查 Info.plist 中的 URL Schemes 是否正确

### 问题 2：登录后返回 App 时没有完成登录
- 确认 Info.plist 已在 Xcode Build Settings 中正确配置
- 确认 Reversed Client ID 格式正确

### 问题 3：Supabase 返回错误
- 确认 Supabase Dashboard 中的 Authorized Client IDs 已填入
- 确认 Skip nonce check 已开启

## 📝 代码结构

```
earthlord/
├── earthlord/
│   ├── Managers/
│   │   ├── AuthManager.swift          # 认证管理器（已集成 Google 登录）
│   │   └── GoogleAuthManager.swift    # Google 登录专用管理器
│   ├── Views/
│   │   └── AuthView.swift             # 认证页面（已添加 Google 登录按钮）
│   ├── earthlordApp.swift             # App 入口（已添加 URL 回调处理）
│   └── Info.plist                     # 配置文件（需要填入 URL Schemes）
```

## 🎯 下一步

1. 按照上述步骤完成配置
2. 测试 Google 登录功能
3. 如果遇到问题，查看控制台日志中的详细错误信息
4. 所有日志都包含中文说明，方便调试

## 📌 重要提示

- **Client ID** 和 **Reversed Client ID** 不同，不要混淆
- 确保在 Supabase Dashboard 中正确填写了 Authorized Client IDs
- 生产环境需要额外配置 App Store Connect 的 Bundle ID
