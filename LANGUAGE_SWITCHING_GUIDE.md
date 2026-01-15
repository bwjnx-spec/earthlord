# iOS App 语言切换功能使用指南

## 功能概述

本项目实现了独立于系统语言设置的 App 内语言切换功能，支持以下特性：

- ✅ 三种语言选项：跟随系统、简体中文、English
- ✅ 切换后立即生效，无需重启 App
- ✅ 用户选择持久化存储，下次打开保持选择
- ✅ 响应式设计，所有视图自动更新

## 使用方法

### 用户操作流程

1. 打开 App，进入「个人」标签页
2. 在设置区域找到「语言设置」选项
3. 点击进入语言选择页面
4. 选择想要的语言：
   - **跟随系统**：使用系统设置的语言
   - **简体中文**：始终使用简体中文
   - **English**：始终使用英文
5. 选择后自动返回，整个 App 的语言立即切换

## 技术实现

### 核心组件

#### 1. LanguageManager

语言管理器，负责：
- 管理当前语言设置
- 持久化用户选择
- 提供本地化字符串
- 发送语言变化通知

```swift
// 获取单例实例
let languageManager = LanguageManager.shared

// 切换语言
languageManager.setLanguage(.english)

// 获取当前语言
let currentLanguage = languageManager.currentLanguage
```

#### 2. AppLanguage 枚举

定义了三种语言选项：

```swift
enum AppLanguage: String, CaseIterable {
    case system              // 跟随系统
    case simplifiedChinese   // 简体中文
    case english             // English
}
```

#### 3. LanguageSettingView

语言选择视图，提供：
- 三个语言选项的可视化界面
- 当前选中状态的显示
- 点击切换语言的交互

### 在新视图中添加语言切换支持

要让你的视图支持语言切换，只需三步：

#### 步骤 1：引入 LanguageManager

```swift
struct YourView: View {
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        // ...
    }
}
```

#### 步骤 2：添加刷新修饰符

```swift
var body: some View {
    VStack {
        // 你的视图内容
    }
    .refreshOnLanguageChange() // 添加这一行
}
```

#### 步骤 3：使用本地化字符串

有三种方式使用本地化字符串：

**方式一：使用 NSLocalizedString（推荐）**

```swift
Text(NSLocalizedString("个人中心", comment: ""))
```

**方式二：使用 String 扩展（简洁）**

```swift
Text("个人中心".localized)
```

**方式三：带参数的本地化**

```swift
Text("验证码已发送到 %@".localized(arguments: email))
```

## 添加新的翻译条目

要添加新的可翻译文本，需要在 `Localizable.xcstrings` 文件中添加对应的条目：

```json
"你的文本" : {
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Your Text"
      }
    }
  }
}
```

## 文件结构

```
earthlord/
├── Managers/
│   └── LanguageManager.swift         # 语言管理器
├── Views/
│   ├── Settings/
│   │   └── LanguageSettingView.swift # 语言选择视图
│   ├── Tabs/
│   │   └── ProfileTabView.swift      # 个人中心（集成语言设置）
│   └── MainTabView.swift             # 主标签页（支持语言切换）
└── Localizable.xcstrings             # 翻译资源文件
```

## 工作原理

### 语言切换流程

1. 用户在 `LanguageSettingView` 中选择语言
2. `LanguageManager.setLanguage()` 被调用
3. 更新 `@Published` 属性 `currentLanguage`
4. 将选择保存到 `UserDefaults`
5. 更新内部的 Bundle（用于本地化）
6. 发送 `languageDidChange` 通知
7. 所有添加了 `.refreshOnLanguageChange()` 的视图自动刷新
8. SwiftUI 重新渲染视图树，显示新语言的文本

### 响应式更新机制

```swift
extension View {
    func refreshOnLanguageChange() -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            // 视图会自动刷新
        }
    }
}
```

当 `LanguageManager.currentLanguage` 改变时：
- 所有 `@ObservedObject` 绑定自动触发更新
- 通过 `NotificationCenter` 通知其他订阅者
- SwiftUI 自动重新计算视图层级

## 注意事项

1. **持久化存储**：用户的语言选择会自动保存到 `UserDefaults`，下次启动时会自动恢复

2. **系统语言检测**：当用户选择"跟随系统"时，App 会自动检测系统语言并使用对应的翻译

3. **翻译缺失处理**：如果某个 key 没有对应语言的翻译，会显示源语言（中文）的文本

4. **性能考虑**：`LanguageManager` 是单例，整个 App 共享同一个实例，避免重复创建

5. **测试建议**：
   - 测试所有三种语言选项
   - 验证切换后的立即生效
   - 检查重启 App 后的语言保持
   - 确认所有界面的文本都正确翻译

## 故障排查

### 问题：切换语言后某些文本没有更新

**解决方案**：
1. 确保该视图添加了 `.refreshOnLanguageChange()` 修饰符
2. 确保使用了 `NSLocalizedString` 或 `.localized` 获取文本
3. 检查 `Localizable.xcstrings` 中是否有对应的翻译

### 问题：编译错误找不到 LanguageManager

**解决方案**：
确保 `LanguageManager.swift` 文件已添加到项目 target

### 问题：翻译显示为 key 而不是文本

**解决方案**：
1. 检查 `Localizable.xcstrings` 文件格式是否正确
2. 确认 key 名称完全匹配（区分大小写）
3. 清理构建缓存：Product → Clean Build Folder

## 最佳实践

1. **统一使用本地化**：所有用户可见的文本都应该使用本地化字符串

2. **及时添加翻译**：添加新文本时，同时在 `Localizable.xcstrings` 中添加英文翻译

3. **语义化命名**：使用有意义的 key 名称，避免使用 "text1"、"label2" 等通用名称

4. **复用翻译**：相同含义的文本使用相同的 key，避免重复翻译

5. **测试覆盖**：每次添加新界面后，都要测试语言切换是否正常工作

## 示例代码

### 完整的视图示例

```swift
import SwiftUI

struct ExampleView: View {
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Text(NSLocalizedString("地球新主", comment: ""))
                .font(.largeTitle)

            Text(NSLocalizedString("探索和圈占领地", comment: ""))
                .font(.body)

            Button(action: {
                // 按钮点击事件
            }) {
                Text(NSLocalizedString("开始探索", comment: ""))
            }
        }
        .refreshOnLanguageChange()
    }
}
```

## 更新日志

- **2025-01-07**：初始实现，支持三种语言选项，实现立即生效和持久化存储

---

如有问题或建议，请联系开发团队。
