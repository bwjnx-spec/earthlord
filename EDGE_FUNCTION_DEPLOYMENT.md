# Supabase 边缘函数部署指南

## 📋 delete-account 函数说明

**功能**：安全地删除用户账户

**工作流程**：
1. 从 Authorization header 验证用户身份（JWT token）
2. 获取当前用户信息
3. 使用 service_role 权限删除用户账户
4. 返回删除结果

**安全特性**：
- ✅ JWT 验证确保只有登录用户可以删除自己的账户
- ✅ 使用 service_role key 执行删除操作
- ✅ 完整的错误处理和日志记录
- ✅ CORS 支持

---

## 🚀 方法 1：使用自动部署脚本（推荐）

### 步骤 1：安装 Supabase CLI

```bash
# macOS
brew install supabase/tap/supabase

# Windows (使用 Scoop)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Linux
brew install supabase/tap/supabase
```

### 步骤 2：运行部署脚本

```bash
cd supabase
./deploy.sh
```

脚本会自动：
1. 检查 Supabase CLI 是否安装
2. 登录到 Supabase（如果需要）
3. 关联项目
4. 部署 delete-account 函数

---

## 🛠️ 方法 2：手动部署

### 步骤 1：安装 Supabase CLI

（同上）

### 步骤 2：登录 Supabase

```bash
supabase login
```

这会打开浏览器进行 OAuth 认证。

### 步骤 3：关联项目

```bash
supabase link --project-ref xlhkojuliphmvmzhpgzw
```

### 步骤 4：部署函数

```bash
supabase functions deploy delete-account --no-verify-jwt
```

**参数说明**：
- `--no-verify-jwt`：跳过 JWT 验证（因为我们在函数内部手动验证）

---

## 🌐 方法 3：通过 Supabase Dashboard 部署

### 步骤 1：登录 Dashboard

访问：https://supabase.com/dashboard/project/xlhkojuliphmvmzhpgzw

### 步骤 2：进入 Edge Functions

导航：Database → Edge Functions → Create a new function

### 步骤 3：创建函数

1. **函数名称**：`delete-account`
2. **代码**：复制 `supabase/functions/delete-account/index.ts` 的内容
3. 点击 **Deploy**

---

## ⚙️ 配置环境变量

部署后，需要在 Supabase Dashboard 中配置环境变量：

### 方法 A：在 Dashboard 中配置

1. 访问：https://supabase.com/dashboard/project/xlhkojuliphmvmzhpgzw/settings/functions
2. 选择 `delete-account` 函数
3. 添加环境变量：
   - `SUPABASE_SERVICE_ROLE_KEY`：你的 service_role key

### 方法 B：使用 CLI 配置

```bash
# 设置 service_role key
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# 列出所有秘密
supabase secrets list
```

**注意**：`SUPABASE_URL` 和 `SUPABASE_ANON_KEY` 会自动注入，无需手动配置。

---

## 🧪 测试函数

### 使用 curl 测试

```bash
# 1. 先登录获取 access_token
# 在你的 App 中登录后，从 Supabase session 中获取 access_token

# 2. 调用删除函数
curl -X POST \
  https://xlhkojuliphmvmzhpgzw.supabase.co/functions/v1/delete-account \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json"
```

### 预期响应

**成功**：
```json
{
  "success": true,
  "message": "账户已成功删除",
  "deleted_user_id": "user-uuid-here",
  "deleted_user_email": "user@example.com"
}
```

**错误（未授权）**：
```json
{
  "error": "未授权",
  "message": "缺少 Authorization header"
}
```

---

## 📱 在 Swift App 中调用

在 `AuthManager.swift` 中添加删除账户方法：

```swift
/// 删除用户账户
func deleteAccount() async throws {
    print("🗑️ 开始删除账户...")

    // 获取当前 session 的 access token
    let session = try await supabase.auth.session

    // 调用边缘函数
    let response: HTTPResponse = try await supabase.functions.invoke(
        "delete-account",
        options: FunctionInvokeOptions(
            headers: ["Authorization": "Bearer \(session.accessToken)"]
        )
    )

    // 解析响应
    if response.status == 200 {
        print("✅ 账户删除成功")
        // 清除本地状态
        await signOut()
    } else {
        let errorData = try? JSONDecoder().decode([String: String].self, from: response.data)
        let errorMessage = errorData?["message"] ?? "删除账户失败"
        print("❌ \(errorMessage)")
        throw NSError(domain: "DeleteAccount", code: Int(response.status),
                     userInfo: [NSLocalizedDescriptionKey: errorMessage])
    }
}
```

### 在 ProfileTabView 中添加删除按钮

```swift
// 删除账户按钮（危险操作）
Button(action: { showDeleteConfirm = true }) {
    HStack {
        Image(systemName: "trash.fill")
        Text("删除账户")
    }
    .foregroundColor(.red)
}
.alert("确认删除账户", isPresented: $showDeleteConfirm) {
    Button("取消", role: .cancel) { }
    Button("永久删除", role: .destructive) {
        Task {
            do {
                try await authManager.deleteAccount()
            } catch {
                // 处理错误
            }
        }
    }
} message: {
    Text("此操作无法撤销。所有数据将被永久删除。")
}
```

---

## 🔍 查看日志

### 方法 1：Supabase Dashboard

1. 访问：https://supabase.com/dashboard/project/xlhkojuliphmvmzhpgzw/logs/edge-functions
2. 选择 `delete-account` 函数
3. 查看实时日志

### 方法 2：CLI

```bash
# 实时查看日志
supabase functions logs delete-account --follow

# 查看最近 100 条日志
supabase functions logs delete-account --limit 100
```

---

## 🐛 故障排查

### 问题 1：部署失败

**错误**：`Failed to deploy function`

**解决方案**：
1. 检查网络连接
2. 确认已登录：`supabase login`
3. 检查项目 ref 是否正确

### 问题 2：401 Unauthorized

**错误**：调用函数返回 401

**解决方案**：
1. 检查 Authorization header 格式：`Bearer YOUR_TOKEN`
2. 确认 token 未过期
3. 使用有效的 access_token

### 问题 3：500 Internal Server Error

**错误**：删除用户失败

**可能原因**：
1. `SUPABASE_SERVICE_ROLE_KEY` 未配置
2. Service role key 不正确
3. 用户 ID 不存在

**解决方案**：
- 检查环境变量配置
- 查看函数日志了解详细错误

---

## 📊 函数监控

### 查看函数统计

```bash
supabase functions list
```

### 性能指标

在 Dashboard 中查看：
- 调用次数
- 平均响应时间
- 错误率
- 日志

---

## 🔐 安全最佳实践

1. ✅ **永不**在客户端代码中暴露 `service_role` key
2. ✅ 始终验证用户身份后再执行敏感操作
3. ✅ 记录所有删除操作的日志
4. ✅ 考虑添加"软删除"功能（标记为已删除而不是真正删除）
5. ✅ 添加删除前的二次确认

---

## 📚 相关资源

- [Supabase Edge Functions 文档](https://supabase.com/docs/guides/functions)
- [Supabase CLI 文档](https://supabase.com/docs/guides/cli)
- [Deno 文档](https://deno.land/manual)

---

## 📁 文件结构

```
supabase/
├── config.toml                          # Supabase 配置
├── .env.example                         # 环境变量模板
├── deploy.sh                            # 自动部署脚本
└── functions/
    └── delete-account/
        └── index.ts                     # 边缘函数代码
```

---

## ✅ 部署清单

- [ ] 安装 Supabase CLI
- [ ] 登录 Supabase
- [ ] 关联项目
- [ ] 部署函数
- [ ] 配置 service_role key
- [ ] 测试函数
- [ ] 在 App 中集成
- [ ] 添加删除确认 UI
- [ ] 测试完整流程
