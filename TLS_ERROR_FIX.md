# 修复 TLS 安全连接错误

## 问题描述
App 尝试连接 Supabase 时出现 TLS 错误："因TSL错误导致安全连接失败"

## 解决方案

### 方案 1：在 Xcode 中配置网络权限和 ATS（推荐）

#### 步骤 1：打开项目设置
1. 在 Xcode 中打开项目
2. 在左侧项目导航器中点击最顶层的项目文件（蓝色图标）
3. 在 TARGETS 中选择 `earthlord`
4. 点击 `Info` 标签页

#### 步骤 2：添加 App Transport Security 配置
1. 在 `Custom iOS Target Properties` 部分，右键点击任意位置
2. 选择 `Add Row`
3. 添加以下配置：

```
Key: App Transport Security Settings (NSAppTransportSecurity)
Type: Dictionary

展开这个 Dictionary，添加子项：

Key: Allow Arbitrary Loads (NSAllowsArbitraryLoads)
Type: Boolean
Value: YES
```

**重要提示**：这个设置允许所有网络请求。在生产环境中，应该使用更安全的配置（见方案 2）。

#### 步骤 3：添加网络权限（iOS 14+）
如果你的项目支持 iOS 14 或更高版本：

1. 点击 `Signing & Capabilities` 标签页
2. 点击 `+ Capability` 按钮
3. 搜索并添加 `Outgoing Connections (Client)`

#### 步骤 4：清理并重新构建
1. Product → Clean Build Folder (Cmd + Shift + K)
2. Product → Build (Cmd + B)
3. 运行 App 测试

---

### 方案 2：仅允许 Supabase 域名（更安全，推荐生产环境）

在 `Info` 标签页中配置：

```
App Transport Security Settings (NSAppTransportSecurity)
├─ Exception Domains (NSExceptionDomains)
   └─ supabase.co
      ├─ NSIncludesSubdomains: YES
      ├─ NSExceptionAllowsInsecureHTTPLoads: NO
      └─ NSExceptionRequiresForwardSecrecy: YES
```

**JSON 格式参考**（如果手动编辑 Info.plist）：
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>supabase.co</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSExceptionRequiresForwardSecrecy</key>
            <true/>
        </dict>
    </dict>
</dict>
```

---

### 方案 3：检查模拟器/设备网络连接

#### 检查项：
1. **模拟器网络**：
   - 确保 Mac 网络连接正常
   - 重启模拟器：Device → Erase All Content and Settings

2. **真机测试**：
   - 检查 iPhone 的网络连接
   - 尝试切换 WiFi 或使用移动数据

3. **测试 Supabase 连接**：
   ```bash
   # 在终端测试
   curl -I https://xlhkojuliphmvmzhpgzw.supabase.co
   ```

---

### 方案 4：添加网络调试（帮助诊断问题）

在 `AuthManager.swift` 或网络请求代码中添加调试信息：

```swift
// 在初始化 Supabase 客户端时添加
let supabaseClient: SupabaseClient = {
    print("🌐 初始化 Supabase 客户端")
    print("   URL: https://xlhkojuliphmvmzhpgzw.supabase.co")

    let client = SupabaseClient(
        supabaseURL: URL(string: "https://xlhkojuliphmvmzhpgzw.supabase.co")!,
        supabaseKey: "sb_publishable_ME9eRLy8bCWswTTsogZeGg_yGnYwteQ",
        options: SupabaseClientOptions(
            auth: .init(
                emitLocalSessionAsInitialSession: true
            )
        )
    )

    print("✅ Supabase 客户端初始化完成")
    return client
}()
```

---

## 详细图解：如何在 Xcode 中配置 ATS

### 1. 打开 Info 标签页
```
Xcode 左侧导航 → 点击项目文件（蓝色图标）
→ TARGETS 列表中选择 earthlord
→ 顶部选择 Info 标签
```

### 2. 添加 ATS 配置
```
在 Custom iOS Target Properties 中：
右键点击 → Add Row → 输入 "App Transport Security Settings"
```

### 3. 完整配置示例
```
Custom iOS Target Properties
├─ App Transport Security Settings (Dictionary)
│  └─ Allow Arbitrary Loads (Boolean) = YES
│
├─ Privacy - Local Network Usage Description (String)
│  └─ "需要访问网络以连接 Supabase 服务器"
```

---

## 常见问题排查

### Q1: 添加了 ATS 配置但仍然报错
**A**:
1. 确保配置的 Key 名称完全正确（区分大小写）
2. 清理构建缓存：Product → Clean Build Folder
3. 重启 Xcode 和模拟器

### Q2: 真机测试可以，模拟器报错
**A**:
1. 检查 Mac 的网络连接
2. 关闭 VPN 或代理
3. 重置模拟器：Device → Erase All Content and Settings

### Q3: 使用 Allow Arbitrary Loads 安全吗？
**A**:
- **开发环境**：可以使用，方便调试
- **生产环境**：应该使用方案 2，仅允许特定域名
- 提交 App Store 时，Apple 可能会要求说明为什么使用此设置

### Q4: 如何查看详细的网络错误信息？
**A**:
在 Xcode 中：
1. Product → Scheme → Edit Scheme
2. Run → Arguments
3. 添加 Environment Variable：
   - Name: `OS_ACTIVITY_MODE`
   - Value: `disable`（减少系统日志干扰）

---

## 验证修复

修复后，运行以下测试：

### 测试 1：注册功能
1. 打开 App
2. 进入注册页面
3. 输入邮箱和密码
4. 点击注册
5. **期望结果**：成功发送验证码或显示其他合理错误（非 TLS 错误）

### 测试 2：登录功能
1. 尝试登录已有账户
2. **期望结果**：成功登录或显示合理错误信息

### 测试 3：查看 Console 日志
运行 App 时查看 Xcode Console：
- ✅ **成功**：看到 "✅ Supabase 客户端初始化完成"
- ✅ **成功**：网络请求能正常发送和接收
- ❌ **失败**：仍然看到 TLS 或 SSL 相关错误

---

## 如果以上方案都不行

### 最后的诊断步骤：

1. **检查 Supabase 服务状态**
   - 访问：https://status.supabase.com
   - 确认服务正常运行

2. **测试网络请求**
   ```swift
   // 在 App 中添加测试代码
   Task {
       do {
           let url = URL(string: "https://xlhkojuliphmvmzhpgzw.supabase.co")!
           let (data, response) = try await URLSession.shared.data(from: url)
           print("✅ 网络请求成功")
           print("   状态码: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
       } catch {
           print("❌ 网络请求失败: \(error)")
       }
   }
   ```

3. **检查 Supabase Key 是否正确**
   - 登录 Supabase Dashboard
   - 进入 Project Settings → API
   - 确认使用的是正确的 `anon/public` key

4. **联系技术支持**
   - 如果问题持续，请提供：
     - 完整的错误信息
     - Xcode 版本
     - iOS 版本
     - 模拟器还是真机
     - Console 完整日志

---

## 推荐配置（总结）

### 开发环境（快速开始）
```
App Transport Security Settings
└─ Allow Arbitrary Loads = YES
```

### 生产环境（安全）
```
App Transport Security Settings
└─ Exception Domains
   └─ supabase.co
      ├─ NSIncludesSubdomains = YES
      ├─ NSExceptionAllowsInsecureHTTPLoads = NO
      └─ NSExceptionRequiresForwardSecrecy = YES
```

---

## 操作视频指南（文字版）

### 在 Xcode 中添加 ATS 配置的完整步骤：

1. **打开项目**
   - 双击 `earthlord.xcodeproj` 文件打开项目

2. **进入项目设置**
   - 点击左侧最顶部的项目图标（蓝色）
   - 确保在 `PROJECT` 和 `TARGETS` 之间选择 `TARGETS`
   - 点击 `earthlord` target

3. **找到 Info 配置**
   - 在顶部标签栏找到 `Info`
   - 看到 `Custom iOS Target Properties` 列表

4. **添加网络权限**
   - 右键点击列表中的任意位置
   - 选择 `Add Row`
   - 输入 `App Transport Security Settings`
   - 类型自动为 `Dictionary`

5. **配置 ATS**
   - 点击 `App Transport Security Settings` 左边的小三角展开
   - 点击展开后的加号 `+`
   - 添加 `Allow Arbitrary Loads`
   - 类型选择 `Boolean`
   - 勾选复选框（设为 YES）

6. **保存并测试**
   - 按 `Cmd + S` 保存
   - 按 `Cmd + Shift + K` 清理构建
   - 按 `Cmd + R` 运行测试

---

完成后，TLS 错误应该就解决了！
