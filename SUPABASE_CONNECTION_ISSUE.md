# ⚠️ Supabase 连接问题诊断报告

## 🔍 问题发现

经测试，你的 Supabase URL 本身无法访问：
```
URL: https://xlhkojuliphmvmzhpgzw.supabase.co
错误: SSL_ERROR_SYSCALL (SSL 连接失败)
```

**这不是 iOS 配置的问题，而是 Supabase 服务本身的问题！**

---

## 🎯 可能的原因

### 1. Supabase 项目已暂停 ⭐ 最可能
Supabase 免费项目在以下情况会被暂停：
- **7 天无活动** → 自动暂停
- **超出免费额度** → 暂停
- **手动暂停** → 在 Dashboard 中暂停了项目

### 2. Supabase 项目已删除
- 项目可能被意外删除
- URL 不再有效

### 3. 网络环境问题
- VPN 阻止了连接
- 防火墙设置
- DNS 解析问题

### 4. Supabase 服务故障（较少见）
- Supabase 平台正在维护
- 区域性服务中断

---

## ✅ 解决方案

### 方案 1：恢复 Supabase 项目（推荐）⭐

#### 步骤 1：登录 Supabase Dashboard
1. 访问：https://supabase.com/dashboard
2. 使用你的账号登录

#### 步骤 2：检查项目状态
你应该会看到项目：**xlhkojuliphmvmzhpgzw**

**如果项目显示为「已暂停」(Paused)**：
1. 点击项目卡片
2. 点击 **"Restore project"** 或 **"Resume"** 按钮
3. 等待 1-2 分钟项目恢复

**如果项目不在列表中**：
- 可能已被删除，需要创建新项目（见方案 2）

#### 步骤 3：验证连接
恢复后，在终端测试：
```bash
curl -I https://xlhkojuliphmvmzhpgzw.supabase.co
```

**期望结果**：
```
HTTP/2 200
```

如果成功，重新运行 iOS App 即可。

---

### 方案 2：创建新的 Supabase 项目

如果项目已删除，需要创建新项目：

#### 步骤 1：创建新项目
1. 访问：https://supabase.com/dashboard
2. 点击 **"New Project"**
3. 填写信息：
   - **Name**: earthlord（或其他名称）
   - **Database Password**: 设置一个强密码（保存好！）
   - **Region**: 选择离你最近的区域（如 Singapore, Tokyo）
   - **Pricing Plan**: Free（免费）
4. 点击 **"Create new project"**
5. 等待 2-3 分钟创建完成

#### 步骤 2：获取新的 URL 和 API Key
创建完成后：
1. 进入项目设置：**Settings** → **API**
2. 复制以下信息：
   - **Project URL**: `https://[your-project-id].supabase.co`
   - **anon/public key**: `eyJ...` (很长的字符串)

#### 步骤 3：更新 iOS 项目配置
在 `RootView.swift` 中更新：

```swift
let supabaseClient: SupabaseClient = {
    return SupabaseClient(
        supabaseURL: URL(string: "https://[你的新项目ID].supabase.co")!,
        supabaseKey: "[你的新 anon key]",
        options: SupabaseClientOptions(
            auth: .init(
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}()
```

#### 步骤 4：重新运行 App
```bash
Cmd + Shift + K  # 清理
Cmd + R          # 运行
```

---

### 方案 3：检查网络环境

#### 测试 1：关闭 VPN
如果你正在使用 VPN：
1. 暂时关闭 VPN
2. 重新测试连接
3. 运行 App

#### 测试 2：切换网络
1. 尝试切换到另一个 WiFi 网络
2. 或使用手机热点
3. 重新测试

#### 测试 3：检查防火墙
在 Mac 上：
1. 系统设置 → 网络 → 防火墙
2. 暂时关闭防火墙测试
3. 或添加 Xcode 到允许列表

---

## 🔧 验证修复

### 1. 终端测试
```bash
curl -I https://xlhkojuliphmvmzhpgzw.supabase.co
```

**成功**应该看到：
```
HTTP/2 200
或
HTTP/2 301
```

**失败**会看到：
```
curl: (35) SSL error
或
curl: (6) Could not resolve host
```

### 2. 在线测试
访问浏览器：
```
https://xlhkojuliphmvmzhpgzw.supabase.co
```

- **成功**：显示 Supabase 页面或 404
- **失败**：无法连接或连接超时

### 3. App 测试
运行 iOS App：
- ✅ 成功：可以注册/登录
- ❌ 失败：仍然显示 TLS 错误

---

## 📊 常见问题

### Q1: 为什么 Supabase 项目会被暂停？
**A**: Supabase 免费项目在 7 天无活动后自动暂停，这是正常的节约资源机制。只需点击恢复即可。

### Q2: 暂停的项目数据会丢失吗？
**A**: 不会！数据仍然保留，恢复项目后数据完整。

### Q3: 如何避免项目被暂停？
**A**:
- 定期使用（至少每周一次）
- 升级到付费计划（$25/月起）
- 设置定时任务定期访问 API

### Q4: 创建新项目后旧数据怎么办？
**A**: 如果旧项目已删除，数据无法恢复。新项目需要重新创建数据库表和导入数据。

### Q5: 我应该选择哪个区域？
**A**:
- 中国用户：Singapore（新加坡）或 Tokyo（东京）
- 速度最快，延迟最低

---

## 🚀 快速行动清单

### 如果你想快速解决问题：

**5 分钟解决方案**：
1. [ ] 登录 Supabase Dashboard
2. [ ] 找到项目 xlhkojuliphmvmzhpgzw
3. [ ] 如果显示「Paused」，点击 Resume
4. [ ] 等待 1-2 分钟
5. [ ] 重新运行 iOS App

**如果项目已删除**：
1. [ ] 创建新的 Supabase 项目（3 分钟）
2. [ ] 复制新的 URL 和 API Key
3. [ ] 更新 `RootView.swift` 中的配置
4. [ ] 重新运行 App

---

## 📞 需要帮助？

如果以上方案都不行，请提供：
1. Supabase Dashboard 的截图
2. 终端测试 curl 的完整输出
3. Xcode Console 的完整错误日志

---

## 💡 预防措施

为了避免将来再次遇到这个问题：

### 1. 定期使用
- 每周至少登录一次 App
- 或设置自动化测试

### 2. 监控项目状态
- 收藏 Supabase Dashboard
- 定期检查项目状态

### 3. 备份配置
- 保存 URL 和 API Key
- 记录数据库结构

### 4. 考虑升级
如果这是重要项目：
- 升级到 Pro 计划（$25/月）
- 项目永不暂停
- 更好的性能和支持

---

## ✅ 总结

**问题根源**：Supabase 项目无法访问（很可能被暂停）

**解决方案**：
1. 恢复暂停的项目 ← 最快
2. 创建新项目 ← 如果已删除
3. 检查网络环境 ← 排除故障

**下一步**：立即登录 Supabase Dashboard 检查项目状态！

完成后，iOS App 应该就能正常连接了。🎉
