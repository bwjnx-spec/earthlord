//
//  NotificationSettingView.swift
//  earthlord
//
//  通知设置页面
//

import SwiftUI
import UserNotifications

struct NotificationSettingView: View {
    @State private var notificationsEnabled = false
    @State private var explorationAlerts = true
    @State private var nearbyPlayerAlerts = true
    @State private var eventAlerts = true
    @State private var dailyReminder = false
    @State private var reminderTime = Date()
    @State private var showPermissionAlert = false
    @State private var isLoading = true

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
                    // 通知权限状态
                    notificationStatusCard

                    // 通知类型设置
                    if notificationsEnabled {
                        notificationTypesCard

                        // 每日提醒
                        dailyReminderCard
                    }

                    // 说明
                    tipsCard

                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .navigationTitle("通知设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            checkNotificationStatus()
        }
        .alert("需要通知权限", isPresented: $showPermissionAlert) {
            Button("去设置") {
                openSettings()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("请在系统设置中开启通知权限，以接收游戏提醒。")
        }
    }

    // MARK: - 通知状态卡片

    private var notificationStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: notificationsEnabled ? "bell.fill" : "bell.slash.fill")
                    .font(.title)
                    .foregroundColor(notificationsEnabled ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)

                VStack(alignment: .leading, spacing: 4) {
                    Text("推送通知")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(notificationsEnabled ? "已开启" : "已关闭")
                        .font(.caption)
                        .foregroundColor(notificationsEnabled ? .green : ApocalypseTheme.textMuted)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                } else {
                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                        .tint(ApocalypseTheme.primary)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            handleNotificationToggle(newValue)
                        }
                }
            }

            if !notificationsEnabled && !isLoading {
                // 提示开启通知
                Button(action: { requestNotificationPermission() }) {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text("开启通知")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 通知类型卡片

    private var notificationTypesCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "list.bullet")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("通知类型")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }
            .padding()

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 探索提醒
            NotificationToggleRow(
                icon: "map.fill",
                title: "探索提醒",
                subtitle: "附近发现新的探索点时通知",
                isOn: $explorationAlerts
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .padding(.horizontal)

            // 附近玩家
            NotificationToggleRow(
                icon: "person.2.fill",
                title: "附近玩家",
                subtitle: "有其他幸存者出现在附近时通知",
                isOn: $nearbyPlayerAlerts
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .padding(.horizontal)

            // 活动通知
            NotificationToggleRow(
                icon: "star.fill",
                title: "活动通知",
                subtitle: "游戏活动和特殊事件提醒",
                isOn: $eventAlerts
            )
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 每日提醒卡片

    private var dailyReminderCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("每日提醒")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Toggle("", isOn: $dailyReminder)
                    .labelsHidden()
                    .tint(ApocalypseTheme.primary)
            }
            .padding()

            if dailyReminder {
                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                HStack {
                    Text("提醒时间")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                }
                .padding()
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 提示卡片

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ApocalypseTheme.info)

                Text("关于通知")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Text("开启通知可以让你及时了解游戏中的重要事件。你可以随时在这里调整通知偏好，或在系统设置中完全关闭通知。")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .lineSpacing(4)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - 方法

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsEnabled = settings.authorizationStatus == .authorized
                self.isLoading = false
            }
        }
    }

    private func handleNotificationToggle(_ enabled: Bool) {
        if enabled {
            requestNotificationPermission()
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    self.notificationsEnabled = true
                } else {
                    self.notificationsEnabled = false
                    self.showPermissionAlert = true
                }
            }
        }
    }

    private func openSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - 辅助视图

struct NotificationToggleRow: View {
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

#Preview {
    NavigationView {
        NotificationSettingView()
    }
}
