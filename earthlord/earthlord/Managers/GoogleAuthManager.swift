import Foundation
import SwiftUI
import GoogleSignIn
import Supabase

/// Google 认证管理器
/// 负责处理 Google 第三方登录流程
@MainActor
class GoogleAuthManager {

    private let supabase: SupabaseClient

    // Google Client ID（从 Google Cloud Console 获取）
    // 需要在使用前设置正确的 Client ID
    private var clientID: String {
        // TODO: 替换为你的 Google Client ID
        // 格式类似：123456789-abcdefghijklmnop.apps.googleusercontent.com
        return "YOUR_GOOGLE_CLIENT_ID"
    }

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    /// 使用 Google 登录
    /// - Returns: Supabase 用户信息（如果成功）
    func signInWithGoogle() async throws -> Supabase.User {
        print("🔵 Google 登录 - 开始流程")

        // 步骤 1: 配置 Google Sign-In
        print("   步骤 1: 配置 Google Sign-In")
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // 步骤 2: 获取顶层视图控制器
        print("   步骤 2: 获取顶层视图控制器")
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("   ❌ 无法获取根视图控制器")
            throw GoogleAuthError.noViewController
        }

        // 步骤 3: 执行 Google 登录
        print("   步骤 3: 调用 Google Sign-In SDK")
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController
        )

        let user = result.user
        print("   ✅ Google 登录成功")
        print("   用户 Email: \(user.profile?.email ?? "未知")")
        print("   用户名称: \(user.profile?.name ?? "未知")")

        // 步骤 4: 获取 ID Token
        print("   步骤 4: 获取 Google ID Token")
        guard let idToken = user.idToken?.tokenString else {
            print("   ❌ 无法获取 ID Token")
            throw GoogleAuthError.noIDToken
        }

        print("   ✅ ID Token 获取成功: \(idToken.prefix(20))...")

        // 步骤 5: 使用 ID Token 登录 Supabase
        print("   步骤 5: 使用 Google ID Token 登录 Supabase")
        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken
            )
        )

        print("   ✅ Supabase 登录成功")
        print("   Supabase 用户 ID: \(session.user.id)")
        print("   Supabase 用户 Email: \(session.user.email ?? "未知")")

        print("🔵 Google 登录 - 流程完成")
        return session.user
    }

    /// 登出 Google
    func signOut() {
        print("🔵 Google 登出")
        GIDSignIn.sharedInstance.signOut()
        print("   ✅ Google 登出完成")
    }
}

/// Google 认证错误
enum GoogleAuthError: LocalizedError {
    case noViewController
    case noIDToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noViewController:
            return "无法获取视图控制器"
        case .noIDToken:
            return "无法获取 Google ID Token"
        case .cancelled:
            return "用户取消了登录"
        }
    }
}
