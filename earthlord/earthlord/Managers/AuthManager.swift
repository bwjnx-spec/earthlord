import Foundation
import Combine
import Supabase
import AuthenticationServices

/// 认证管理器
/// 负责处理用户注册、登录、密码重置等认证流程
@MainActor
class AuthManager: ObservableObject {

    // MARK: - Published Properties

    /// 用户是否已完成认证（已登录且完成所有必要流程）
    @Published var isAuthenticated: Bool = false

    /// 是否需要设置密码（OTP 验证后的强制密码设置）
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published var currentUser: User? = nil

    /// 加载状态
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String? = nil

    /// OTP 是否已发送
    @Published var otpSent: Bool = false

    /// OTP 是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - Private Properties

    private let supabase: SupabaseClient

    /// Apple User ID 存储 Key
    private static let appleUserIDKey = "earthlord_apple_user_id"

    // MARK: - Initialization

    init(supabase: SupabaseClient) {
        self.supabase = supabase
        setupAppleCredentialRevocationListener()
    }

    // MARK: - Apple 凭证管理

    /// 保存 Apple User ID
    func saveAppleUserID(_ userID: String) {
        UserDefaults.standard.set(userID, forKey: Self.appleUserIDKey)
        print("🍎 已保存 Apple User ID")
    }

    /// 清除 Apple User ID
    private func clearAppleUserID() {
        UserDefaults.standard.removeObject(forKey: Self.appleUserIDKey)
    }

    /// 获取已保存的 Apple User ID
    private var savedAppleUserID: String? {
        UserDefaults.standard.string(forKey: Self.appleUserIDKey)
    }

    /// 检查 Apple 凭证状态（启动时调用）
    func checkAppleCredentialState() async {
        guard let appleUserID = savedAppleUserID else {
            // 不是 Apple 登录的用户，跳过
            return
        }

        print("🍎 检查 Apple 凭证状态...")

        do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: appleUserID)

            switch state {
            case .authorized:
                print("🍎 Apple 凭证有效")
            case .revoked:
                print("🍎 Apple 凭证已撤销，自动登出")
                clearAppleUserID()
                await signOut()
            case .notFound:
                print("🍎 Apple 凭证未找到，自动登出")
                clearAppleUserID()
                await signOut()
            case .transferred:
                print("🍎 Apple 凭证已转移")
            @unknown default:
                break
            }
        } catch {
            print("🍎 检查 Apple 凭证失败: \(error.localizedDescription)")
        }
    }

    /// 监听 Apple 凭证撤销通知
    private func setupAppleCredentialRevocationListener() {
        NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                print("🍎 收到 Apple 凭证撤销通知")
                self.clearAppleUserID()
                await self.signOut()
            }
        }
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 使用数字验证码方式注册（而不是魔法链接）
            try await supabase.auth.signInWithOTP(
                email: email,
                redirectTo: nil,  // 不使用重定向链接
                shouldCreateUser: true,
                captchaToken: nil
            )

            otpSent = true
            print("✅ 注册验证码已发送到: \(email)")
            print("ℹ️ 请检查邮箱，输入收到的6位数字验证码")

        } catch {
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            print("❌ 发送注册 OTP 失败: \(error)")
        }

        isLoading = false
    }

    /// 验证注册验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    /// - Note: 验证成功后用户已登录，但需要设置密码才能完成注册
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP，type 为 .email
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功，用户已登录
            otpVerified = true
            needsPasswordSetup = true

            // 获取用户信息
            let supabaseUser = session.user
            currentUser = User(
                id: supabaseUser.id.uuidString,
                email: supabaseUser.email,
                createdAt: supabaseUser.createdAt
            )

            // 注意：此时 isAuthenticated 保持 false，直到设置密码
            print("✅ 验证码验证成功，等待设置密码")

        } catch {
            errorMessage = "验证码验证失败: \(error.localizedDescription)"
            print("❌ 验证注册 OTP 失败: \(error)")
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户密码
    /// - Note: 注册流程的最后一步，设置密码后用户才算完全注册成功
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            let updatedUser = try await supabase.auth.update(
                user: UserAttributes(password: password)
            )

            // 注册完成
            needsPasswordSetup = false
            isAuthenticated = true

            // 更新用户信息
            currentUser = User(
                id: updatedUser.id.uuidString,
                email: updatedUser.email,
                createdAt: updatedUser.createdAt
            )

            print("✅ 注册完成，密码已设置")

        } catch {
            // 处理特定的密码错误
            let errorDescription = error.localizedDescription

            // 如果是"新密码与旧密码相同"的错误，说明账户可能已经设置过密码
            // 这种情况下，直接完成注册流程
            if errorDescription.contains("should be different") ||
               errorDescription.contains("same password") ||
               errorDescription.lowercased().contains("different from the old password") {

                print("⚠️ 检测到密码可能已设置，直接完成注册")
                needsPasswordSetup = false
                isAuthenticated = true
                self.errorMessage = nil

            } else {
                // 其他错误正常显示
                self.errorMessage = "设置密码失败: \(errorDescription)"
                print("❌ 完成注册失败: \(error)")
            }
        }

        isLoading = false
    }

    // MARK: - 登录流程

    /// 使用邮箱和密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        print("🔑 开始登录: \(email)")
        isLoading = true
        errorMessage = nil

        do {
            print("   调用 supabase.auth.signIn...")
            // 使用邮箱密码登录
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            print("   登录 API 调用成功")
            print("   会话 ID: \(session.accessToken.prefix(20))...")

            // 登录成功，直接设置为已认证
            isAuthenticated = true
            needsPasswordSetup = false

            print("   ✅ isAuthenticated 已设置为: \(isAuthenticated)")

            // 获取用户信息
            let supabaseUser = session.user
            currentUser = User(
                id: supabaseUser.id.uuidString,
                email: supabaseUser.email,
                createdAt: supabaseUser.createdAt
            )

            print("✅ 登录成功: \(email)")
            print("   用户 ID: \(supabaseUser.id.uuidString)")
            print("   isAuthenticated: \(isAuthenticated)")
            print("   currentUser: \(currentUser?.email ?? "nil")")

        } catch {
            errorMessage = "登录失败: \(error.localizedDescription)"
            print("❌ 登录失败: \(error)")
        }

        isLoading = false
        print("🔑 登录流程结束 - isAuthenticated: \(isAuthenticated)")
    }

    // MARK: - 找回密码流程

    /// 发送密码重置验证码
    /// - Parameter email: 用户邮箱
    /// - Note: 使用 OTP 方式重置密码（6位数字验证码）
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 使用 OTP 方式发送密码重置验证码
            // 注意：这会发送6位数字码，而不是重置链接
            try await supabase.auth.resetPasswordForEmail(
                email,
                redirectTo: nil  // 不使用重定向链接
            )

            otpSent = true
            print("✅ 密码重置验证码已发送到: \(email)")
            print("ℹ️ 请检查邮箱，输入收到的6位数字验证码")

        } catch {
            errorMessage = "发送重置验证码失败: \(error.localizedDescription)"
            print("❌ 发送重置 OTP 失败: \(error)")
        }

        isLoading = false
    }

    /// 验证密码重置验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    /// - Note: ⚠️ type 必须是 .recovery 而不是 .email
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证密码重置 OTP，type 为 .recovery
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )

            // 验证成功
            otpVerified = true
            needsPasswordSetup = true

            // 获取用户信息
            let supabaseUser = session.user
            currentUser = User(
                id: supabaseUser.id.uuidString,
                email: supabaseUser.email,
                createdAt: supabaseUser.createdAt
            )

            print("✅ 重置验证码验证成功，等待设置新密码")

        } catch {
            errorMessage = "验证码验证失败: \(error.localizedDescription)"
            print("❌ 验证重置 OTP 失败: \(error)")
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新密码
            let updatedUser = try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            // 密码重置完成
            needsPasswordSetup = false
            isAuthenticated = true

            // 更新用户信息
            currentUser = User(
                id: updatedUser.id.uuidString,
                email: updatedUser.email,
                createdAt: updatedUser.createdAt
            )

            print("✅ 密码重置成功")

        } catch {
            errorMessage = "重置密码失败: \(error.localizedDescription)"
            print("❌ 重置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 第三方登录

    /// 使用 Apple 登录
    func signInWithApple() async {
        print("🍎 开始 Apple 登录流程")
        isLoading = true
        errorMessage = nil

        do {
            let appleAuthManager = AppleAuthManager(supabase: supabase)
            let (supabaseUser, appleUserID) = try await appleAuthManager.signInWithApple()

            // 保存 Apple User ID 用于静默登录检查
            if let appleUserID {
                saveAppleUserID(appleUserID)
            }

            isAuthenticated = true
            needsPasswordSetup = false

            currentUser = User(
                id: supabaseUser.id.uuidString,
                email: supabaseUser.email,
                createdAt: supabaseUser.createdAt
            )

            print("✅ Apple 登录完成")
            print("   用户 ID: \(supabaseUser.id.uuidString)")
            print("   用户 Email: \(supabaseUser.email ?? "隐藏")")

        } catch let error as AppleAuthError where error == .cancelled {
            print("⚠️ 用户取消了 Apple 登录")
        } catch {
            errorMessage = "Apple 登录失败: \(error.localizedDescription)"
            print("❌ Apple 登录失败: \(error)")
            isAuthenticated = false
        }

        isLoading = false
        print("🍎 Apple 登录流程结束")
    }

    /// 使用 Apple ID Token 登录（由 SignInWithAppleButton 回调使用）
    func signInWithAppleToken(identityToken: String) async {
        print("🍎 Apple Token 登录 - 开始")
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: identityToken
                )
            )

            isAuthenticated = true
            needsPasswordSetup = false

            let supabaseUser = session.user
            currentUser = User(
                id: supabaseUser.id.uuidString,
                email: supabaseUser.email,
                createdAt: supabaseUser.createdAt
            )

            print("✅ Apple Token 登录完成")
            print("   用户 ID: \(supabaseUser.id.uuidString)")

        } catch {
            errorMessage = "Apple 登录失败: \(error.localizedDescription)"
            print("❌ Apple Token 登录失败: \(error)")
            isAuthenticated = false
        }

        isLoading = false
    }

    /// 使用 Google 登录
    func signInWithGoogle() async {
        print("🔵 开始 Google 登录流程")
        isLoading = true
        errorMessage = nil

        do {
            // 创建 Google 认证管理器
            let googleAuthManager = GoogleAuthManager(supabase: supabase)

            // 执行 Google 登录并获取 Supabase 用户
            print("   调用 Google 登录...")
            let supabaseUser = try await googleAuthManager.signInWithGoogle()

            // 登录成功，设置认证状态
            isAuthenticated = true
            needsPasswordSetup = false

            // 更新用户信息
            currentUser = User(
                id: supabaseUser.id.uuidString,
                email: supabaseUser.email,
                createdAt: supabaseUser.createdAt
            )

            print("✅ Google 登录完成")
            print("   用户 ID: \(supabaseUser.id.uuidString)")
            print("   用户 Email: \(supabaseUser.email ?? "未知")")
            print("   isAuthenticated: \(isAuthenticated)")

        } catch {
            // 处理登录错误
            errorMessage = "Google 登录失败: \(error.localizedDescription)"
            print("❌ Google 登录失败: \(error)")
            isAuthenticated = false
        }

        isLoading = false
        print("🔵 Google 登录流程结束")
    }

    // MARK: - 其他方法

    /// 登出
    func signOut() async {
        print("🚪 开始登出...")
        isLoading = true
        errorMessage = nil

        do {
            print("   调用 supabase.auth.signOut()")
            try await supabase.auth.signOut()

            print("   清除本地状态...")
            // 重置所有状态
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false
            clearAppleUserID()

            print("✅ 登出成功")
            print("   isAuthenticated: \(isAuthenticated)")
            print("   currentUser: \(currentUser?.email ?? "nil")")

        } catch {
            errorMessage = "登出失败: \(error.localizedDescription)"
            print("❌ 登出失败: \(error)")

            // 即使登出失败，也清除本地状态
            print("   强制清除本地状态")
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false
            clearAppleUserID()
        }

        isLoading = false
        print("🚪 登出流程结束")
    }

    /// 删除用户账户
    /// - Note: 调用 Supabase 边缘函数永久删除账户
    func deleteAccount() async throws {
        print("🗑️ 开始删除账户流程...")
        print("   当前用户: \(currentUser?.email ?? "未知")")

        isLoading = true
        errorMessage = nil

        do {
            // 获取当前会话的 access token
            print("   步骤 1: 获取当前会话...")
            let session = try await supabase.auth.session

            print("   步骤 2: 调用边缘函数 delete-account...")
            print("   使用 token: \(session.accessToken.prefix(20))...")

            // 调用边缘函数删除账户
            let response: DeleteAccountResponse = try await supabase.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(
                    method: .post
                )
            )

            print("   步骤 3: 解析响应...")
            print("   ✅ 边缘函数调用成功")
            print("   账户删除成功!")
            print("   删除的用户 ID: \(response.deleted_user_id)")
            print("   删除的邮箱: \(response.deleted_user_email)")

            // 清除本地状态
            print("   步骤 4: 清除本地状态...")
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false

            print("✅ 账户删除完成，已清除本地数据")

        } catch let error as DeleteAccountError {
            // 已知错误类型
            errorMessage = error.localizedDescription
            print("❌ 删除账户失败: \(error.localizedDescription)")
            throw error

        } catch {
            // 未知错误
            let errorMsg = "删除账户失败: \(error.localizedDescription)"
            errorMessage = errorMsg
            print("❌ \(errorMsg)")
            throw DeleteAccountError.serverError(error.localizedDescription)
        }

        isLoading = false
        print("🗑️ 删除账户流程结束")
    }

    /// 检查当前会话
    /// - Note: 应用启动时调用，恢复登录状态
    func checkSession() async {
        isLoading = true

        // 先检查 Apple 凭证是否仍然有效（已撤销则自动登出）
        await checkAppleCredentialState()

        do {
            // 获取当前会话
            let session = try await supabase.auth.session

            // 检查会话是否过期
            if session.isExpired {
                print("⚠️ 会话已过期，需要重新登录")
                isAuthenticated = false
                currentUser = nil
                // 清除过期会话
                try? await supabase.auth.signOut()
            } else {
                // 会话有效，恢复用户状态
                let supabaseUser = session.user
                currentUser = User(
                    id: supabaseUser.id.uuidString,
                    email: supabaseUser.email,
                    createdAt: supabaseUser.createdAt
                )

                // 用户已登录且会话有效
                isAuthenticated = true
                needsPasswordSetup = false

                print("✅ 会话已恢复: \(supabaseUser.email ?? "未知邮箱")")
            }

        } catch {
            // 没有会话或会话过期
            isAuthenticated = false
            currentUser = nil
            print("ℹ️ 没有活动会话: \(error.localizedDescription)")
        }

        isLoading = false
    }
}

// MARK: - 删除账户相关数据模型

/// 删除账户成功响应
struct DeleteAccountResponse: Codable {
    let success: Bool
    let message: String
    let deleted_user_id: String
    let deleted_user_email: String
}

/// 删除账户错误
enum DeleteAccountError: LocalizedError {
    case serverError(String)
    case networkError
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .serverError(let message):
            return message
        case .networkError:
            return "网络连接失败，请检查网络后重试"
        case .unauthorized:
            return "未授权，请重新登录"
        }
    }
}
