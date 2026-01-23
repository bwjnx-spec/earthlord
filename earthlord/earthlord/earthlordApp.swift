//
//  earthlordApp.swift
//  earthlord
//
//  Created by 何小宝 on 2025/12/23.
//

import SwiftUI
import Combine
import Auth
import Supabase
import GoogleSignIn

@main
struct earthlordApp: App {
    /// 全局认证管理器
    @StateObject private var authManager = AuthManager(supabase: supabaseClient)
    /// 语言管理器
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    // 已登录 → 主界面
                    ContentView()
                        .environmentObject(authManager)
                        .onAppear {
                            print("✅ 已进入主界面")
                            print("   用户: \(authManager.currentUser?.email ?? "未知")")
                        }
                } else {
                    // 未登录 → 登录页
                    AuthView(authManager: authManager)
                        .onAppear {
                            print("📱 显示登录页面")
                        }
                }
            }
            .environment(\.locale, languageManager.currentLocale)
            .environmentObject(languageManager)
            .id(languageManager.refreshID) // 语言切换时强制刷新整个视图树
            .onAppear {
                print("🚀 应用启动")

                // DEBUG 模式清除会话
                #if DEBUG
                Task {
                    print("🔧 DEBUG: 清除缓存会话")
                    try? await supabaseClient.auth.signOut()
                    await MainActor.run {
                        authManager.isAuthenticated = false
                        authManager.currentUser = nil
                    }
                }
                #endif
            }
            .onChange(of: authManager.isAuthenticated) { _, newValue in
                print("🔐 认证状态变化: \(newValue)")
            }
            .task {
                // 监听认证状态变化
                setupAuthStateListener()
            }
            .onOpenURL { url in
                // 处理 Google Sign-In 回调 URL
                print("🔗 收到 URL 回调: \(url)")
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }

    /// 设置认证状态监听器
    private func setupAuthStateListener() {
        Task {
            for await state in supabaseClient.auth.authStateChanges {
                await MainActor.run {
                    switch state.event {
                    case .signedIn:
                        print("🔐 用户已登录: \(state.session?.user.email ?? "未知")")
                        authManager.isAuthenticated = true

                    case .signedOut:
                        print("🚪 用户已登出（会话过期或主动登出）")
                        authManager.isAuthenticated = false
                        authManager.currentUser = nil
                        authManager.needsPasswordSetup = false
                        authManager.otpSent = false
                        authManager.otpVerified = false
                        print("   已清除所有认证状态，即将跳转到登录页")

                    case .userUpdated:
                        print("👤 用户信息已更新")

                    case .passwordRecovery:
                        print("🔑 密码恢复中")

                    case .tokenRefreshed:
                        print("🔄 Token 已刷新")

                    case .mfaChallengeVerified:
                        print("✅ MFA 验证完成")

                    case .initialSession:
                        print("📋 初始会话加载")

                    case .userDeleted:
                        print("🗑️ 用户已删除")
                        authManager.isAuthenticated = false
                        authManager.currentUser = nil
                    }
                }
            }
        }
    }
}
