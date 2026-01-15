import SwiftUI
import Supabase

struct ProfileTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var deleteConfirmText = ""
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

    var body: some View {
        NavigationView {
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

                ScrollView {
                    VStack(spacing: 24) {
                        // 用户信息卡片
                        userInfoCard

                        // 功能列表
                        settingsSection

                        // 退出登录按钮
                        logoutButton

                        // 删除账户按钮
                        deleteAccountButton

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("个人中心")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .alert("确认退出", isPresented: $showLogoutConfirm) {
            Button("取消", role: .cancel) { }
            Button("退出", role: .destructive) {
                Task {
                    await handleLogout()
                }
            }
        } message: {
            Text("确定要退出登录吗？")
        }
        .refreshOnLanguageChange()
    }

    // MARK: - 用户信息卡片

    private var userInfoCard: some View {
        VStack(spacing: 16) {
            // 用户头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primary.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10)

            // 用户信息
            VStack(spacing: 8) {
                if let email = authManager.currentUser?.email {
                    Text(email)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                } else {
                    Text("未知用户")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                if let userId = authManager.currentUser?.id {
                    Text("ID: \(String(userId.prefix(8)))...")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                // 账户状态
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)

                    Text("已登录")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 设置选项

    private var settingsSection: some View {
        VStack(spacing: 0) {
            settingRow(
                icon: "shield.fill",
                title: "账户安全",
                subtitle: "密码、隐私设置"
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.2))
                .padding(.horizontal)

            settingRow(
                icon: "bell.fill",
                title: "通知设置",
                subtitle: "管理推送通知"
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.2))
                .padding(.horizontal)

            // 语言设置 - 可导航
            NavigationLink(destination: LanguageSettingView()) {
                settingRowContent(
                    icon: "globe",
                    title: "语言设置",
                    subtitle: languageManager.currentLanguage.displayName
                )
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.2))
                .padding(.horizontal)

            settingRow(
                icon: "info.circle.fill",
                title: "关于",
                subtitle: "版本 1.0.0"
            )
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    private func settingRow(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            // TODO: 实现对应功能
            print("⚠️ 功能开发中")
        }
    }

    /// 设置行内容（用于 NavigationLink）
    private func settingRowContent(icon: String, title: LocalizedStringKey, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding()
        .contentShape(Rectangle())
    }

    // MARK: - 退出登录按钮

    private var logoutButton: some View {
        Button(action: { showLogoutConfirm = true }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.headline)

                Text("退出登录")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(ApocalypseTheme.danger)
            .cornerRadius(12)
        }
    }

    // MARK: - 删除账户按钮

    private var deleteAccountButton: some View {
        Button(action: { showDeleteConfirm = true }) {
            HStack {
                Image(systemName: "trash.fill")
                    .font(.headline)

                Text("删除账户")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.red.opacity(0.8), Color.red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
        }
        .alert("危险操作", isPresented: $showDeleteConfirm) {
            TextField("请输入\"删除\"以确认", text: $deleteConfirmText)
                .autocapitalization(.none)

            Button("取消", role: .cancel) {
                deleteConfirmText = ""
            }

            Button("确认删除", role: .destructive) {
                Task {
                    await handleDeleteAccount()
                }
            }
            .disabled(deleteConfirmText != L("删除"))
        } message: {
            Text("此操作不可撤销！删除账户将永久清除所有数据。\n\n请在下方输入\"删除\"以确认操作。")
        }
        .alert("删除失败", isPresented: $showDeleteError) {
            Button("确定", role: .cancel) {
                deleteErrorMessage = ""
            }
        } message: {
            Text(deleteErrorMessage)
        }
    }

    // MARK: - 登出处理

    private func handleLogout() async {
        print("🚪 用户点击退出登录")
        await authManager.signOut()
        print("   登出完成，等待视图切换到登录页")
    }

    // MARK: - 删除账户处理

    private func handleDeleteAccount() async {
        print("🗑️ 用户确认删除账户")
        print("   输入的确认文本: \(deleteConfirmText)")

        // 验证确认文本（使用 L() 获取本地化的"删除"关键词）
        let deleteKeyword = L("删除")
        guard deleteConfirmText == deleteKeyword else {
            print("   ❌ 确认文本不匹配，取消删除")
            deleteConfirmText = ""
            return
        }

        do {
            print("   调用 AuthManager.deleteAccount()")
            try await authManager.deleteAccount()
            print("   ✅ 账户删除成功")
            deleteConfirmText = ""
        } catch {
            print("   ❌ 删除账户失败: \(error.localizedDescription)")
            deleteErrorMessage = String(format: L("删除账户失败：%@"), error.localizedDescription)
            showDeleteError = true
            deleteConfirmText = ""
        }
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(AuthManager(supabase: supabaseClient))
}
