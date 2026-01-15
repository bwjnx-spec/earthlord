# ⚠️ TLS 错误完整解决方案

## 🎯 问题根本原因

经过诊断，发现问题**不是 iOS 配置的问题**，而是：

**Supabase 服务器本身无法连接！**

```
测试结果：curl: (35) SSL_ERROR_SYSCALL
原因：Supabase 项目很可能已被暂停或删除
```

---

## ⚡ 立即行动（5分钟解决）

### 步骤 1：检查 Supabase 项目状态

1. **登录 Supabase**
   ```
   访问：https://supabase.com/dashboard
   ```

2. **找到你的项目**
   - 项目名称/ID：`xlhkojuliphmvmzhpgzw`

3. **检查状态**
   - ✅ 如果显示「**Paused**」（已暂停）
     → 点击 **"Resume"** 按钮恢复项目
     → 等待 1-2 分钟
     → 完成！跳到步骤 2

   - ❌ 如果项目不在列表中
     → 项目已删除，需要创建新项目
     → 查看下面"创建新项目"部分

### 步骤 2：验证修复

在终端运行：
```bash
curl -I https://xlhkojuliphmvmzhpgzw.supabase.co
```

**成功**应该看到：
```
HTTP/2 200
```

或在 iOS App 中：
1. 打开 App
2. 进入「更多」标签
3. 点击「网络诊断工具」
4. 点击「开始测试」
5. 查看测试结果

### 步骤 3：重新运行 App

```
Xcode: Cmd + R
```

TLS 错误应该消失了！✅

---

## 🆕 如果需要创建新项目

### 1. 创建 Supabase 项目

1. 访问：https://supabase.com/dashboard
2. 点击 **"New Project"**
3. 填写：
   - Name: `earthlord`
   - Database Password: [设置强密码并保存]
   - Region: `Singapore` 或 `Tokyo`（推荐）
   - Plan: `Free`
4. 点击 **"Create new project"**
5. 等待 2-3 分钟

### 2. 获取新的连接信息

项目创建后：
1. 进入 **Settings** → **API**
2. 复制：
   - **Project URL**: `https://[new-id].supabase.co`
   - **anon public key**: `eyJ...`（很长）

### 3. 更新 iOS 项目

编辑 `earthlord/Views/RootView.swift`：

```swift
let supabaseClient: SupabaseClient = {
    return SupabaseClient(
        // 👇 替换为新的 URL
        supabaseURL: URL(string: "https://[新的项目ID].supabase.co")!,
        // 👇 替换为新的 Key
        supabaseKey: "[新的 anon key]",
        options: SupabaseClientOptions(
            auth: .init(
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}()
```

### 4. 运行测试

```bash
Cmd + Shift + K  # 清理
Cmd + R          # 运行
```

---

## 📁 已创建的文件

我已经为你创建了以下文件：

### 1. **Info.plist** ✅
- 位置：`earthlord/earthlord/Info.plist`
- 包含：网络安全配置（ATS）
- 状态：已配置好，可直接使用

### 2. **NetworkDiagnosticsView.swift** ✅
- 位置：`earthlord/earthlord/Views/NetworkDiagnosticsView.swift`
- 功能：App 内网络诊断工具
- 使用：「更多」标签 → 「网络诊断工具」

### 3. **文档文件** ✅
- `SUPABASE_CONNECTION_ISSUE.md` - 详细问题分析
- `TLS_ERROR_FIX.md` - TLS 配置指南
- `QUICK_FIX_TLS.md` - 快速修复步骤
- `Info.plist.example` - 配置示例

---

## 🔧 在 Xcode 中配置 Info.plist（重要！）

即使我创建了 Info.plist 文件，你还需要告诉 Xcode 使用它：

### 方法 1：在 Xcode 中添加文件（推荐）

1. 在 Xcode 左侧导航器中，右键点击 `earthlord` 文件夹
2. 选择 **"Add Files to earthlord..."**
3. 找到并选择刚创建的 `Info.plist`
4. 确保勾选：
   - ✅ Copy items if needed
   - ✅ Add to targets: earthlord
5. 点击 **"Add"**

### 方法 2：在 Build Settings 中配置

1. 点击项目文件（蓝色图标）
2. 选择 TARGET → earthlord
3. 点击 **"Build Settings"**
4. 搜索 `Info.plist`
5. 找到 **"Info.plist File"**
6. 设置值为：`earthlord/Info.plist`

---

## 🧪 使用网络诊断工具

我在 App 中添加了诊断工具，可以直接测试：

### 使用步骤：
1. 运行 App
2. 进入底部「**更多**」标签
3. 点击「**网络诊断工具**」
4. 点击「**开始测试**」
5. 查看详细的测试结果和错误分析

### 诊断工具会告诉你：
- ✅ DNS 是否能解析
- ✅ HTTPS 连接是否成功
- ✅ Supabase API 是否响应
- ❌ 具体的错误原因
- 💡 针对性的解决建议

---

## ❓ 常见问题

### Q: 为什么 Supabase 项目会暂停？
**A**: 免费项目在 **7 天无活动**后自动暂停，这是 Supabase 的节约资源机制。

### Q: 暂停后数据会丢失吗？
**A**: **不会！**只需点击恢复，数据完整保留。

### Q: 如何避免再次暂停？
**A**:
- 每周至少使用一次 App
- 或升级到付费计划（$25/月）

### Q: 我的 Mac 能访问这个 URL，为什么 App 不行？
**A**: 如果能在浏览器访问，但 App 报错，那确实是 ATS 配置问题。请确保：
1. Info.plist 文件已添加到项目
2. ATS 配置正确
3. 清理并重新构建

### Q: 创建新项目后需要重新配置数据库吗？
**A**: 是的。新项目是全新的，需要：
1. 创建数据库表
2. 设置 Row Level Security (RLS)
3. 配置 Auth 设置
4. 重新导入数据（如果有）

---

## 📞 需要更多帮助？

如果问题仍未解决，请提供：

1. **Supabase Dashboard 截图**
   - 显示项目状态

2. **终端测试结果**
   ```bash
   curl -v https://xlhkojuliphmvmzhpgzw.supabase.co 2>&1
   ```

3. **App 诊断结果**
   - 使用「网络诊断工具」的完整输出

4. **Xcode Console 日志**
   - 完整的错误信息

---

## ✅ 检查清单

在报告问题前，请确认：

- [ ] 已登录 Supabase Dashboard 检查项目状态
- [ ] 如果项目暂停，已点击恢复
- [ ] 已在终端测试 URL 可访问性
- [ ] 已运行 App 内的网络诊断工具
- [ ] 已清理构建缓存（Cmd + Shift + K）
- [ ] 已重启 Xcode
- [ ] 已尝试关闭 VPN
- [ ] 已查看 Info.plist 是否正确配置

---

## 🎉 预期结果

完成上述步骤后：

✅ **成功标志**：
- Supabase 项目状态：Active（活跃）
- 终端测试：HTTP/2 200
- App 诊断：所有测试通过
- App 功能：注册/登录正常工作

❌ **仍然失败**：
- 查看 SUPABASE_CONNECTION_ISSUE.md
- 使用网络诊断工具获取详细错误
- 提供完整信息寻求帮助

---

## 💡 总结

**问题根源**: Supabase 项目无法访问（暂停/删除）

**解决方案**:
1. 恢复暂停的项目 ← **最快**
2. 创建新项目 ← 如果已删除
3. 配置 Info.plist ← 确保 ATS 设置

**验证方法**:
- 终端 curl 测试
- App 网络诊断工具
- 实际功能测试

立即行动，5 分钟解决问题！🚀
