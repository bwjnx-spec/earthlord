# Xcode URL Schemes 配置指南

## ⚠️ 为什么删除了 Info.plist？

在现代 Xcode 项目中，Info.plist 的配置可以直接在 Xcode 的 Target 设置中完成，无需单独的 Info.plist 文件。创建单独的文件会导致 "Multiple commands produce Info.plist" 错误。

---

## 🔧 在 Xcode 中配置 Google Sign-In URL Schemes

### 步骤 1：打开项目设置

1. 打开 `earthlord.xcodeproj`
2. 在左侧导航栏选择项目 `earthlord`
3. 在 TARGETS 列表中选择 `earthlord`

### 步骤 2：配置 URL Types

1. 选择 **Info** 选项卡
2. 找到 **URL Types** 部分
3. 点击 **+** 按钮添加新的 URL Type

### 步骤 3：添加 Google Sign-In URL Scheme

在新添加的 URL Type 中填入：

| 字段 | 值 |
|------|-----|
| **Identifier** | `com.google.signin` |
| **URL Schemes** | `com.googleusercontent.apps.431220526072-jadsbrvusm6budts89a10t3nj97f0ftc` |
| **Role** | `Editor` |

**重要说明**：
- URL Schemes 字段填入的是 **Reversed Client ID**
- 格式：`com.googleusercontent.apps.YOUR-CLIENT-ID`
- 对应的原始 Client ID：`431220526072-jadsbrvusm6budts89a10t3nj97f0ftc.apps.googleusercontent.com`

### 步骤 4：验证配置

1. 在 Xcode 中按 `Cmd + B` 构建项目
2. 确保没有 "Multiple commands produce" 错误
3. 构建成功后，可以测试 Google 登录

---

## 🎯 完整的 URL Type 配置截图示例

```
URL Types
├─ URL Type 1
   ├─ Identifier: com.google.signin
   ├─ URL Schemes: com.googleusercontent.apps.431220526072-jadsbrvusm6budts89a10t3nj97f0ftc
   ├─ Icon: (空)
   └─ Role: Editor
```

---

## 🔍 验证配置是否生效

### 方法 1：查看生成的 Info.plist

1. 构建项目（`Cmd + B`）
2. 在 Xcode 左侧导航栏展开 `Products`
3. 右键点击 `earthlord.app` → Show in Finder
4. 右键 `earthlord.app` → Show Package Contents
5. 查看 `Info.plist` 文件，应该包含：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.431220526072-jadsbrvusm6budts89a10t3nj97f0ftc</string>
        </array>
    </dict>
</array>
```

### 方法 2：运行项目测试

1. 运行项目
2. 点击 "使用 Google 登录"
3. 登录后应该能正确返回到 App

---

## 🐛 故障排查

### 问题 1：构建错误 "Multiple commands produce Info.plist"

**原因**：存在多个 Info.plist 文件

**解决方案**：
1. 删除项目中手动创建的 `Info.plist` 文件
2. 仅在 Xcode Target 设置中配置
3. Clean Build Folder (`Cmd + Shift + K`)
4. 重新构建

### 问题 2：Google 登录后无法返回 App

**原因**：URL Scheme 配置不正确

**解决方案**：
1. 检查 URL Schemes 值是否为 Reversed Client ID
2. 确认格式：`com.googleusercontent.apps.YOUR-CLIENT-ID`
3. 不要包含 `.apps.googleusercontent.com` 后缀

### 问题 3：URL Scheme 不生效

**原因**：配置未正确应用

**解决方案**：
1. Clean Build Folder (`Cmd + Shift + K`)
2. 删除 DerivedData：`rm -rf ~/Library/Developer/Xcode/DerivedData`
3. 重启 Xcode
4. 重新构建项目

---

## 📋 完整配置清单

- [x] 删除手动创建的 `Info.plist` 文件
- [ ] 在 Xcode Target → Info → URL Types 中添加配置
- [ ] Identifier: `com.google.signin`
- [ ] URL Schemes: `com.googleusercontent.apps.431220526072-jadsbrvusm6budts89a10t3nj97f0ftc`
- [ ] Role: `Editor`
- [ ] Clean Build Folder
- [ ] 重新构建项目
- [ ] 测试 Google 登录功能

---

## 🔗 相关文档

- [Google Sign-In iOS 配置文档](https://developers.google.com/identity/sign-in/ios/start-integrating)
- [Xcode URL Schemes 文档](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)

---

## 📝 注意事项

1. **不要**在项目中手动创建 `Info.plist` 文件
2. **始终**在 Xcode Target 设置中配置 URL Schemes
3. **确保** Reversed Client ID 格式正确
4. **每次修改**后需要 Clean Build Folder

---

现在你可以重新构建项目了！如果还有问题，请检查上述配置清单。
