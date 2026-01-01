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

    /// 是否显示启动页
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    // 启动页
                    SplashView(isFinished: $showSplash, authManager: authManager)
                        .transition(.opacity)
                } else if authManager.isAuthenticated {
                    // 已登录 → 主界面
                    ContentView()
                        .transition(.opacity)
                        .environmentObject(authManager)
                        .onAppear {
                            print("📱 显示主界面 ContentView")
                        }
                } else {
                    // 未登录 → 登录页
                    AuthView(authManager: authManager)
                        .transition(.opacity)
                        .onAppear {
                            print("🔑 显示登录页 AuthView")
                        }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showSplash)
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .onAppear {
                print("🚀 App 启动 - showSplash: \(showSplash), isAuthenticated: \(authManager.isAuthenticated)")
            }
            .onChange(of: showSplash) { newValue in
                print("📊 showSplash 变化: \(newValue), isAuthenticated: \(authManager.isAuthenticated)")
                // 启动页完成后才开始监听认证状态变化
                if !newValue {
                    print("🎬 启动页完成，开始监听认证状态")
                    setupAuthStateListener()
                }
            }
            .onChange(of: authManager.isAuthenticated) { newValue in
                print("🔐 认证状态变化: \(newValue)")
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
