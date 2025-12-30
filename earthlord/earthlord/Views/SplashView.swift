import SwiftUI
import Auth
import Supabase

/// 启动页视图
struct SplashView: View {
    /// 是否显示加载动画
    @State private var isAnimating = false

    /// 加载进度文字
    @State private var loadingText = "正在初始化..."

    /// Logo 缩放动画
    @State private var logoScale: CGFloat = 0.8

    /// Logo 透明度
    @State private var logoOpacity: Double = 0

    /// 是否完成加载
    @Binding var isFinished: Bool

    /// 认证管理器
    @ObservedObject var authManager: AuthManager

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.18),
                    Color(red: 0.09, green: 0.13, blue: 0.24),
                    Color(red: 0.06, green: 0.06, blue: 0.10)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Logo
                ZStack {
                    // 外圈光晕（呼吸动画）
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    ApocalypseTheme.primary.opacity(0.3),
                                    ApocalypseTheme.primary.opacity(0)
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: isAnimating
                        )

                    // Logo 圆形背景
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
                        .frame(width: 120, height: 120)
                        .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 20)

                    // 地球图标
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // 标题
                VStack(spacing: 8) {
                    Text("地球新主")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("EARTH LORD")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .tracking(4)
                }
                .opacity(logoOpacity)

                Spacer()

                // 加载指示器
                VStack(spacing: 16) {
                    // 三点加载动画
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(ApocalypseTheme.primary)
                                .frame(width: 10, height: 10)
                                .scaleEffect(isAnimating ? 1.0 : 0.5)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }

                    // 加载文字
                    Text(loadingText)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startAnimations()
            performStartupTasks()
        }
    }

    // MARK: - 动画方法

    private func startAnimations() {
        // Logo 入场动画
        withAnimation(.easeOut(duration: 0.8)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // 启动循环动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = true
        }
    }

    // MARK: - 启动任务

    private func performStartupTasks() {
        Task {
            // 第一步：初始化
            loadingText = "正在初始化..."
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8秒

            // 第二步：检查会话
            loadingText = "检查登录状态..."

            #if DEBUG
            // 开发模式：清除会话以便测试
            print("🔧 DEBUG: 清除缓存会话")
            try? await supabaseClient.auth.signOut()
            authManager.isAuthenticated = false
            authManager.currentUser = nil
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            #else
            // 生产模式：检查会话
            await authManager.checkSession()
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            #endif

            // 第三步：加载完成
            loadingText = "准备就绪"
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

            // 完成启动，关闭启动页
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isFinished = true
                }
            }
        }
    }
}

#Preview {
    SplashView(
        isFinished: .constant(false),
        authManager: AuthManager(supabase: supabaseClient)
    )
}
