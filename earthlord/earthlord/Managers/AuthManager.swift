import Foundation
import Combine
import Supabase

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

    // MARK: - Initialization

    init(supabase: SupabaseClient) {
        self.supabase = supabase
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
        isLoading = true
        errorMessage = nil

        do {
            // 使用邮箱密码登录
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            // 登录成功，直接设置为已认证
            isAuthenticated = true
            needsPasswordSetup = false

            // 获取用户信息
            let supabaseUser = session.user
            currentUser = User(
                id: supabaseUser.id.uuidString,
                email: supabaseUser.email,
                createdAt: supabaseUser.createdAt
            )

            print("✅ 登录成功: \(email)")

        } catch {
            errorMessage = "登录失败: \(error.localizedDescription)"
            print("❌ 登录失败: \(error)")
        }

        isLoading = false
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

    // MARK: - 第三方登录（预留）

    /// 使用 Apple 登录
    /// - Note: TODO: 实现 Apple Sign In
    func signInWithApple() async {
        // TODO: 实现 Apple 第三方登录
        print("⚠️ Apple 登录功能待实现")
    }

    /// 使用 Google 登录
    /// - Note: TODO: 实现 Google Sign In
    func signInWithGoogle() async {
        // TODO: 实现 Google 第三方登录
        print("⚠️ Google 登录功能待实现")
    }

    // MARK: - 其他方法

    /// 登出
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()

            // 重置所有状态
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false

            print("✅ 已登出")

        } catch {
            errorMessage = "登出失败: \(error.localizedDescription)"
            print("❌ 登出失败: \(error)")
        }

        isLoading = false
    }

    /// 检查当前会话
    /// - Note: 应用启动时调用，恢复登录状态
    func checkSession() async {
        isLoading = true

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
