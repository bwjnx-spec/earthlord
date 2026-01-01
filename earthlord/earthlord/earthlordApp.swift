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

@main
struct earthlordApp: App {
    /// 全局认证管理器
    @StateObject private var authManager = AuthManager(supabase: supabaseClient)

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
            .onChange(of: authManager.isAuthenticated) { newValue in
                print("🔐 认证状态变化: \(newValue)")
            }
            .task {
                // 监听认证状态变化
                setupAuthStateListener()
            }
        }
    }

    /// 设置认证状态监听器
    private func setupAuthStateListener() {
        Task {
            for await state in await supabaseClient.auth.authStateChanges {
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

                    @unknown default:
                        print("❓ 未知认证事件")
                    }
                }
            }
        }
    }
}
