import Foundation
import AuthenticationServices
import Supabase

/// Apple 认证管理器
/// 负责处理 Apple 第三方登录流程
@MainActor
class AppleAuthManager: NSObject {

    private let supabase: SupabaseClient
    private var continuation: CheckedContinuation<(Supabase.User, String?), Error>?

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    /// 使用 Apple 登录
    /// - Returns: (Supabase 用户信息, Apple User ID)
    func signInWithApple() async throws -> (Supabase.User, String?) {
        print("🍎 Apple 登录 - 开始流程")

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email, .fullName]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthManager: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                print("   ❌ 无法获取 Apple ID Token")
                continuation?.resume(throwing: AppleAuthError.noIDToken)
                continuation = nil
                return
            }

            let appleUserID = credential.user
            print("   ✅ Apple ID Token 获取成功")
            print("   Apple User ID: \(appleUserID)")

            do {
                let session = try await supabase.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: identityToken
                    )
                )

                print("   ✅ Supabase 登录成功")
                print("   用户 ID: \(session.user.id)")
                continuation?.resume(returning: (session.user, appleUserID))
            } catch {
                print("   ❌ Supabase 登录失败: \(error)")
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                print("   ⚠️ 用户取消了 Apple 登录")
                continuation?.resume(throwing: AppleAuthError.cancelled)
            } else {
                print("   ❌ Apple 登录失败: \(error)")
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleAuthManager: ASAuthorizationControllerPresentationContextProviding {

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            return windowScene?.windows.first ?? UIWindow()
        }
    }
}

// MARK: - Apple 认证错误

enum AppleAuthError: LocalizedError {
    case noIDToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noIDToken:
            return "无法获取 Apple ID Token"
        case .cancelled:
            return "用户取消了登录"
        }
    }
}
