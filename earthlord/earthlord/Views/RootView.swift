import SwiftUI
import Combine
import Supabase

// 全局 Supabase 客户端实例
// 注：关于 emitLocalSessionAsInitialSession 的警告已通过在 checkSession 中添加 session.isExpired 检查来处理
let supabaseClient = SupabaseClient(
    supabaseURL: URL(string: "https://xlhkojuliphmvmzhpgzw.supabase.co")!,
    supabaseKey: "sb_publishable_ME9eRLy8bCWswTTsogZeGg_yGnYwteQ"
)

/// 根视图：控制启动页、登录页与主界面的切换
struct RootView: View {
    /// 启动页是否完成
    @State private var splashFinished = false

    /// 认证管理器
    @StateObject private var authManager = AuthManager(supabase: supabaseClient)

    /// 是否已初始化（用于控制首次加载）
    @State private var isInitialized = false

    var body: some View {
        ZStack {
            if !splashFinished {
                // 启动页
                SplashView(isFinished: $splashFinished, authManager: authManager)
                    .transition(.opacity)
            } else if !authManager.isAuthenticated {
                // 登录页
                AuthView(authManager: authManager)
                    .transition(.opacity)
            } else {
                // 主界面
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .onAppear {
            // 开发环境：启动时清除所有缓存会话
            #if DEBUG
            Task {
                print("🔧 DEBUG: 清除所有缓存会话，确保显示登录界面")
                do {
                    try await supabaseClient.auth.signOut()
                    print("✅ 会话已清除")
                } catch {
                    print("ℹ️ 没有需要清除的会话")
                }
            }
            #endif
        }
        .task {
            // 只在首次加载时执行
            guard !isInitialized else { return }
            isInitialized = true

            #if !DEBUG
            // 生产环境才检查缓存会话
            await authManager.checkSession()
            #endif
        }
    }
}

#Preview {
    RootView()
}
