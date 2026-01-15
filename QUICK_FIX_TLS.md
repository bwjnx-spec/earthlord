# 🚀 TLS 错误快速修复（5 分钟解决）

## ⚡ 最快解决方案

### 步骤 1：打开项目设置（30 秒）
1. 在 Xcode 中打开项目
2. 点击左侧最顶部的蓝色项目图标
3. 在 TARGETS 中选择 `earthlord`
4. 点击顶部的 `Info` 标签

### 步骤 2：添加网络权限（2 分钟）

在 `Custom iOS Target Properties` 列表中：

1. **右键点击任意位置** → 选择 `Add Row`

2. **输入配置**：
   ```
   Key: App Transport Security Settings
   Type: Dictionary (自动识别)
   ```

3. **展开刚才添加的项**（点击左边小三角）→ 点击 `+` 号

4. **添加子项**：
   ```
   Key: Allow Arbitrary Loads
   Type: Boolean
   Value: ✅ 勾选（设为 YES）
   ```

### 步骤 3：重新编译运行（1 分钟）
```
Cmd + Shift + K   (清理构建)
Cmd + R          (运行)
```

## ✅ 完成！

TLS 错误应该已经解决了。现在可以正常使用 Supabase 连接。

---

## 📸 配置截图参考

### 最终配置应该像这样：

```
Custom iOS Target Properties
├─ App Transport Security Settings     [Dictionary]
│  └─ Allow Arbitrary Loads            [Boolean] = ✅ YES
```

---

## ❓ 如果还是不行

### 检查 1：确认配置正确
- Key 名称是否完全正确（包括大小写）
- Boolean 是否已勾选

### 检查 2：清理缓存
```bash
# 在终端运行
cd /Users/hexiaobao/Downloads/白文娟——地球新主复刻/earthlord
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

然后在 Xcode 中：
```
Product → Clean Build Folder
Product → Run
```

### 检查 3：重启 Xcode
1. 完全退出 Xcode
2. 重新打开项目
3. 再次运行

---

## 🔒 生产环境注意事项

当前配置 `Allow Arbitrary Loads = YES` 适合：
- ✅ 开发阶段
- ✅ 快速测试
- ✅ 学习和原型开发

发布到 App Store 前，建议改用更安全的配置：
- 参考 `TLS_ERROR_FIX.md` 中的"方案 2"
- 仅允许 Supabase 域名

---

## 📞 需要帮助？

如果问题仍未解决，请查看详细指南：
- 📖 `TLS_ERROR_FIX.md` - 完整故障排查指南
- 📄 `Info.plist.example` - 配置文件示例

或提供以下信息寻求帮助：
1. Xcode 版本
2. iOS 版本（模拟器或真机）
3. Console 中的完整错误信息
