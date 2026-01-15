import SwiftUI

struct LanguageSettingView: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingSuccessToast = false

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    ApocalypseTheme.background,
                    Color(red: 0.05, green: 0.05, blue: 0.08)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 提示文字
                Text("选择您偏好的显示语言")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 语言选项列表
                VStack(spacing: 0) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        languageOptionRow(for: language)

                        if language != AppLanguage.allCases.last {
                            Divider()
                                .background(ApocalypseTheme.textMuted.opacity(0.2))
                                .padding(.horizontal)
                        }
                    }
                }
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical, 16)

            // 切换成功提示
            if showingSuccessToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("语言已切换")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(25)
                    .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("语言设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Language Option Row

    private func languageOptionRow(for language: AppLanguage) -> some View {
        Button(action: {
            guard languageManager.currentLanguage != language else { return }

            // 切换语言
            withAnimation(.easeInOut(duration: 0.2)) {
                languageManager.setLanguage(language)
            }

            // 显示成功提示
            withAnimation(.spring()) {
                showingSuccessToast = true
            }

            // 2秒后隐藏提示并返回
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showingSuccessToast = false
                }
            }
        }) {
            HStack(spacing: 16) {
                // 语言图标
                Image(systemName: languageIcon(for: language))
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 32)

                // 语言名称
                VStack(alignment: .leading, spacing: 4) {
                    Text(languageDisplayName(for: language))
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if language == .system {
                        Text(systemLanguageHint)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }

                Spacer()

                // 选中标记
                if languageManager.currentLanguage == language {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(ApocalypseTheme.primary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
            .background(
                languageManager.currentLanguage == language
                    ? ApocalypseTheme.primary.opacity(0.1)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helper Methods

    /// 获取语言显示名称的本地化 Key
    private func languageDisplayName(for language: AppLanguage) -> LocalizedStringKey {
        switch language {
        case .system:
            return "跟随系统"
        case .simplifiedChinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    private func languageIcon(for language: AppLanguage) -> String {
        switch language {
        case .system:
            return "globe"
        case .simplifiedChinese:
            return "character.textbox"
        case .english:
            return "textformat.abc"
        }
    }

    private var systemLanguageHint: LocalizedStringKey {
        let systemLang = Locale.preferredLanguages.first ?? "en"
        let isChineseSystem = systemLang.hasPrefix("zh")

        if isChineseSystem {
            return "当前系统语言：简体中文"
        } else {
            return "当前系统语言：English"
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSettingView()
    }
}
