import Foundation
import SwiftUI
import Combine

/// 语言选项
enum AppLanguage: String, CaseIterable {
    case system = "system"           // 跟随系统
    case simplifiedChinese = "zh-Hans" // 简体中文
    case english = "en"              // English

    /// 显示名称（根据当前语言设置显示）
    var displayName: String {
        switch self {
        case .system:
            // 根据当前有效语言返回对应翻译
            let code = LanguageManager.shared.effectiveLanguageCode
            return code.hasPrefix("zh") ? "跟随系统" : "System Default"
        case .simplifiedChinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    /// 语言代码（用于本地化）
    var languageCode: String? {
        switch self {
        case .system:
            return nil // 返回 nil 表示使用系统语言
        case .simplifiedChinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }

    /// 获取 Locale
    var locale: Locale {
        switch self {
        case .system:
            return Locale.current
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        }
    }
}

/// 语言管理器 - 支持实时切换语言，无需重启 App
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    // MARK: - Published Properties

    @Published private(set) var currentLanguage: AppLanguage {
        didSet {
            saveLanguagePreference()
            updateBundle()
            // 发送通知，让整个应用重新渲染
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }

    /// 当前使用的 Locale（用于 SwiftUI environment）
    @Published private(set) var currentLocale: Locale = .current

    /// 刷新触发器（用于强制视图刷新）
    @Published var refreshID = UUID()

    // MARK: - Private Properties

    private let userDefaultsKey = "app_language_preference"

    /// 当前语言对应的本地化 Bundle
    private var localizedBundle: Bundle = .main

    // MARK: - Initialization

    private init() {
        // 从 UserDefaults 读取用户选择
        if let savedLanguage = UserDefaults.standard.string(forKey: userDefaultsKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .system
        }

        updateBundle()
    }

    // MARK: - Public Methods

    /// 切换语言
    func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        print("🌐 切换语言到: \(language.rawValue)")
        currentLanguage = language
        // 更新刷新 ID 强制所有视图刷新
        refreshID = UUID()
    }

    /// 获取当前有效的语言代码
    var effectiveLanguageCode: String {
        if let code = currentLanguage.languageCode {
            return code
        }
        // 使用系统语言
        let systemLang = Locale.preferredLanguages.first ?? "en"
        // 处理 zh-Hans-CN 等格式
        if systemLang.hasPrefix("zh") {
            return "zh-Hans"
        }
        return String(systemLang.prefix(2))
    }

    /// 获取本地化字符串（核心方法 - 实现实时切换）
    func localizedString(_ key: String, comment: String = "") -> String {
        return localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// 获取带参数的本地化字符串
    func localizedString(_ key: String, arguments: CVarArg...) -> String {
        let format = localizedString(key)
        return String(format: format, arguments: arguments)
    }

    // MARK: - Private Methods

    /// 保存语言偏好到 UserDefaults
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: userDefaultsKey)
        print("💾 语言偏好已保存: \(currentLanguage.rawValue)")
    }

    /// 更新本地化 Bundle
    private func updateBundle() {
        let languageCode = effectiveLanguageCode

        // 尝试加载对应语言的 lproj
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            localizedBundle = bundle
            print("✅ 已加载语言 Bundle: \(languageCode)")
        } else {
            // 回退到主 Bundle
            localizedBundle = .main
            print("⚠️ 未找到语言 Bundle: \(languageCode)，使用默认")
        }

        // 更新 Locale
        currentLocale = Locale(identifier: languageCode)
        print("📍 当前 Locale: \(currentLocale.identifier)")
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - View Extension

extension View {
    /// 监听语言变化并刷新视图
    func refreshOnLanguageChange() -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            // 触发视图刷新
        }
        .id(LanguageManager.shared.refreshID)
    }

    /// 应用当前语言设置
    func applyLanguage() -> some View {
        self
            .environment(\.locale, LanguageManager.shared.currentLocale)
            .id(LanguageManager.shared.refreshID)
    }
}

// MARK: - String Extension

extension String {
    /// 使用 LanguageManager 获取本地化字符串（实时生效）
    var localized: String {
        LanguageManager.shared.localizedString(self)
    }

    /// 带参数的本地化字符串
    func localized(arguments: CVarArg...) -> String {
        let format = LanguageManager.shared.localizedString(self)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - LocalizedString Helper

/// 便捷函数：获取本地化字符串（用于非 SwiftUI 场景）
func L(_ key: String) -> String {
    LanguageManager.shared.localizedString(key)
}

/// 便捷函数：获取 LocalizedStringKey（用于 SwiftUI Text 等组件）
/// 这样 SwiftUI 会根据 .environment(\.locale) 自动选择正确的翻译
func LK(_ key: String) -> LocalizedStringKey {
    LocalizedStringKey(key)
}
