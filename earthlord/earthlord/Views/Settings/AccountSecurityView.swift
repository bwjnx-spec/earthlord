//
//  AccountSecurityView.swift
//  earthlord
//
//  账户安全设置页面
//

import SwiftUI
import Supabase

struct AccountSecurityView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var showChangePassword = false
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChangingPassword = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    // 隐私设置（持久化到 UserDefaults）
    @AppStorage("privacy_showLocationToPlayers") private var showLocationToPlayers = true
    @AppStorage("privacy_showOnlineStatus") private var showOnlineStatus = true

    var body: some View {
        ZStack {
            // 背景
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
                    // 账户信息卡片
                    accountInfoCard

                    // 安全选项
                    securityOptionsCard

                    // 隐私设置
                    privacySettingsCard

                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .navigationTitle("账户安全")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showChangePassword) {
            changePasswordSheet
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - 账户信息卡片

    private var accountInfoCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("账户信息")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 邮箱
            HStack {
                Text("登录邮箱")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text(authManager.currentUser?.email ?? "未知")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 用户ID
            HStack {
                Text("用户 ID")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                if let userId = authManager.currentUser?.id {
                    Text(String(userId.prefix(8)) + "...")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            // 注册时间
            HStack {
                Text("注册时间")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                if let createdAt = authManager.currentUser?.createdAt {
                    Text(formatDate(createdAt))
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                } else {
                    Text("未知")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 安全选项卡片

    private var securityOptionsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "shield.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("安全设置")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }
            .padding()

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 修改密码
            Button(action: { showChangePassword = true }) {
                HStack {
                    Image(systemName: "key.fill")
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.info)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("修改密码")
                            .font(.body)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("定期更换密码可提高账户安全性")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding()
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .padding(.horizontal)

            // 登录设备管理（占位）
            HStack {
                Image(systemName: "iphone")
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.info)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("登录设备")
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("当前设备")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                Spacer()

                Text("1 台")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding()
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 隐私设置卡片

    private var privacySettingsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("隐私设置")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }
            .padding()

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 位置共享
            PrivacyToggleRow(
                icon: "location.fill",
                title: "显示位置给附近玩家",
                subtitle: "关闭后其他玩家将无法看到你",
                isOn: $showLocationToPlayers
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .padding(.horizontal)

            // 在线状态
            PrivacyToggleRow(
                icon: "circle.fill",
                title: "显示在线状态",
                subtitle: "关闭后将以离线状态显示",
                isOn: $showOnlineStatus
            )
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 修改密码弹窗

    private var changePasswordSheet: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // 说明文字
                    Text("请输入当前密码和新密码")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.top)

                    VStack(spacing: 16) {
                        // 当前密码
                        SecureField("当前密码", text: $currentPassword)
                            .textFieldStyle(ApocalypseTextFieldStyle())

                        // 新密码
                        SecureField("新密码（至少6位）", text: $newPassword)
                            .textFieldStyle(ApocalypseTextFieldStyle())

                        // 确认新密码
                        SecureField("确认新密码", text: $confirmPassword)
                            .textFieldStyle(ApocalypseTextFieldStyle())
                    }
                    .padding(.horizontal)

                    // 密码要求提示
                    VStack(alignment: .leading, spacing: 8) {
                        PasswordRequirementRow(text: "至少 6 个字符", isMet: newPassword.count >= 6)
                        PasswordRequirementRow(text: "两次输入一致", isMet: !newPassword.isEmpty && newPassword == confirmPassword)
                    }
                    .padding(.horizontal)

                    Spacer()

                    // 确认按钮
                    Button(action: { Task { await changePassword() } }) {
                        HStack {
                            if isChangingPassword {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isChangingPassword ? "修改中..." : "确认修改")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canChangePassword ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        .cornerRadius(12)
                    }
                    .disabled(!canChangePassword || isChangingPassword)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("修改密码")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        resetPasswordFields()
                        showChangePassword = false
                    }
                }
            }
        }
    }

    // MARK: - 辅助属性和方法

    private var canChangePassword: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 6 &&
        newPassword == confirmPassword
    }

    private func changePassword() async {
        isChangingPassword = true

        do {
            // 调用 Supabase 更新密码
            try await supabaseClient.auth.update(user: .init(password: newPassword))

            await MainActor.run {
                isChangingPassword = false
                resetPasswordFields()
                showChangePassword = false
                alertTitle = "修改成功"
                alertMessage = "密码已成功修改，下次登录请使用新密码。"
                showAlert = true
            }
        } catch {
            await MainActor.run {
                isChangingPassword = false
                alertTitle = "修改失败"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func resetPasswordFields() {
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - 辅助视图

struct PrivacyToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(ApocalypseTheme.info)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(ApocalypseTheme.primary)
        }
        .padding()
    }
}

struct PasswordRequirementRow: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(isMet ? .green : ApocalypseTheme.textMuted)

            Text(text)
                .font(.caption)
                .foregroundColor(isMet ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)
        }
    }
}

// MARK: - 自定义输入框样式

struct ApocalypseTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
            .foregroundColor(ApocalypseTheme.textPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    NavigationView {
        AccountSecurityView()
            .environmentObject(AuthManager(supabase: supabaseClient))
    }
}
