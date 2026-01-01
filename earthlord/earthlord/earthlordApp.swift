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
            VStack {
                Text("EarthLord - 调试模式")
                    .font(.title)
                    .padding()

                Text("如果能看到下面的登录界面，说明一切正常")
                    .foregroundColor(.secondary)
                    .padding()

                Divider()

                // 直接嵌入登录页面
                AuthView(authManager: authManager)
            }
            .onAppear {
                print("✅✅✅ 应用已启动 ✅✅✅")
                print("   authManager: \(authManager)")
                print("   isAuthenticated: \(authManager.isAuthenticated)")

                // 强制重置状态
                authManager.isAuthenticated = false
                authManager.currentUser = nil
                print("   状态已重置为未登录")
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
                        print("🚪 用户已登出")
                        authManager.isAuthenticated = false
                        authManager.currentUser = nil

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
