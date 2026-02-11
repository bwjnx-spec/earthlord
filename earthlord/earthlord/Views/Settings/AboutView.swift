//
//  AboutView.swift
//  earthlord
//
//  关于页面
//

import SwiftUI

struct AboutView: View {
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
                VStack(spacing: 32) {
                    // App 图标和名称
                    appHeaderSection

                    // 版本信息
                    versionInfoCard

                    // 开发者信息
                    developerInfoCard

                    // 链接
                    linksCard

                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .navigationTitle("关于")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - App 头部

    private var appHeaderSection: some View {
        VStack(spacing: 16) {
            // App 图标
            ZStack {
                RoundedRectangle(cornerRadius: 24)
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
                    .frame(width: 100, height: 100)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 15)

                Text("🌍")
                    .font(.system(size: 50))
            }

            VStack(spacing: 8) {
                Text("地球新主")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("Earth Lord")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("末日生存探索游戏")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - 版本信息卡片

    private var versionInfoCard: some View {
        VStack(spacing: 0) {
            AboutInfoRow(label: "版本", value: "1.0.0")

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .padding(.horizontal)

            AboutInfoRow(label: "构建版本", value: "1")

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .padding(.horizontal)

            AboutInfoRow(label: "系统要求", value: "iOS 16.0+")
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 开发者信息卡片

    private var developerInfoCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "hammer.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("开发信息")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }
            .padding()

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            AboutInfoRow(label: "开发者", value: "Bai Wenjuan")

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .padding(.horizontal)

            AboutInfoRow(label: "版权", value: "© 2025")

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .padding(.horizontal)

            AboutInfoRow(label: "联系邮箱", value: "bwjnx@qq.com")
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 链接卡片

    private var linksCard: some View {
        VStack(spacing: 0) {
            // 技术支持
            Button(action: { openURL("https://bwjnx-spec.github.io/earthlord-support/") }) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.info)
                        .frame(width: 28)

                    Text("技术支持")
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding()
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .padding(.horizontal)

            // 隐私政策
            Button(action: { openURL("https://bwjnx-spec.github.io/earthlord-support/privacy.html") }) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.info)
                        .frame(width: 28)

                    Text("隐私政策")
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding()
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 辅助方法

    private func openURL(_ urlString: String) {
        #if os(iOS)
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - 辅助视图

struct AboutInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding()
    }
}

#Preview {
    NavigationView {
        AboutView()
    }
}
