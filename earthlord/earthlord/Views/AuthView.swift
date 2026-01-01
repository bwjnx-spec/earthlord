import SwiftUI
import Combine
import Supabase

/// 认证页面
/// 包含登录、注册和找回密码功能
struct AuthView: View {

    @ObservedObject var authManager: AuthManager

    // Tab 选择
    @State private var selectedTab: AuthTab = .login

    // 登录表单
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    // 注册表单
    @State private var registerEmail = ""
    @State private var registerOTP = ""
    @State private var registerPassword = ""
    @State private var registerPasswordConfirm = ""
    @State private var registerStep: RegisterStep = .email

    // 重置密码表单
    @State private var resetEmail = ""
    @State private var resetOTP = ""
    @State private var resetPassword = ""
    @State private var resetPasswordConfirm = ""
    @State private var resetStep: ResetStep = .email
    @State private var showResetSheet = false

    // 倒计时
    @State private var registerCountdown = 0
    @State private var resetCountdown = 0
    @State private var registerTimer: Timer?
    @State private var resetTimer: Timer?

    enum AuthTab {
        case login, register
    }

    enum RegisterStep {
        case email      // 输入邮箱
        case otp        // 输入验证码
        case password   // 设置密码
    }

    enum ResetStep {
        case email      // 输入邮箱
        case otp        // 输入验证码
        case password   // 设置新密码
    }

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    ApocalypseTheme.background,
                    Color(red: 0.05, green: 0.05, blue: 0.08)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Logo 和标题
                    VStack(spacing: 16) {
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 80))
                            .foregroundColor(ApocalypseTheme.primary)

                        Text("地球新主")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .padding(.top, 60)

                    // Tab 切换
                    tabSelector

                    // 错误提示
                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(ApocalypseTheme.danger)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(ApocalypseTheme.danger.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal, 32)
                    }

                    // 内容区域
                    if selectedTab == .login {
                        loginView
                    } else {
                        registerView
                    }

                    // 第三方登录
                    thirdPartyLoginView

                    Spacer(minLength: 40)
                }
            }
        }
        .sheet(isPresented: $showResetSheet) {
            resetPasswordSheet
        }
        .onChange(of: authManager.otpVerified) { verified in
            // 注册流程：OTP 验证后自动进入密码设置步骤
            if verified && selectedTab == .register {
                registerStep = .password
            }
        }
        .onAppear {
            print("✅ AuthView 已显示")
            print("   - isAuthenticated: \(authManager.isAuthenticated)")
            print("   - selectedTab: \(selectedTab)")
        }
    }

    // MARK: - Tab 选择器

    private var tabSelector: some View {
        HStack(spacing: 0) {
            // 登录 Tab
            Button(action: { selectedTab = .login }) {
                Text("登录")
                    .font(.headline)
                    .foregroundColor(selectedTab == .login ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == .login ?
                        ApocalypseTheme.cardBackground :
                        Color.clear
                    )
            }

            // 注册 Tab
            Button(action: { selectedTab = .register }) {
                Text("注册")
                    .font(.headline)
                    .foregroundColor(selectedTab == .register ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == .register ?
                        ApocalypseTheme.cardBackground :
                        Color.clear
                    )
            }
        }
        .background(ApocalypseTheme.background)
        .cornerRadius(8)
        .padding(.horizontal, 32)
    }

    // MARK: - 登录视图

    private var loginView: some View {
        VStack(spacing: 20) {
            // 邮箱输入
            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $loginEmail,
                keyboardType: .emailAddress
            )

            // 密码输入
            CustomSecureField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $loginPassword
            )

            // 登录按钮
            Button(action: handleLogin) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(authManager.isLoading ? "登录中..." : "登录")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ApocalypseTheme.primary)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(authManager.isLoading || loginEmail.isEmpty || loginPassword.isEmpty)
            .opacity((authManager.isLoading || loginEmail.isEmpty || loginPassword.isEmpty) ? 0.6 : 1.0)

            // 忘记密码
            Button(action: { showResetSheet = true }) {
                Text("忘记密码？")
                    .font(.footnote)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - 注册视图

    private var registerView: some View {
        VStack(spacing: 20) {
            // 根据步骤显示不同内容
            switch registerStep {
            case .email:
                registerEmailStep
            case .otp:
                registerOTPStep
            case .password:
                registerPasswordStep
            }
        }
        .padding(.horizontal, 32)
    }

    // 注册第一步：输入邮箱
    private var registerEmailStep: some View {
        VStack(spacing: 20) {
            Text("输入邮箱获取验证码")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $registerEmail,
                keyboardType: .emailAddress
            )

            Button(action: handleSendRegisterOTP) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(authManager.isLoading ? "发送中..." : "发送验证码")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ApocalypseTheme.primary)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(authManager.isLoading || registerEmail.isEmpty)
            .opacity((authManager.isLoading || registerEmail.isEmpty) ? 0.6 : 1.0)
        }
    }

    // 注册第二步：输入验证码
    private var registerOTPStep: some View {
        VStack(spacing: 20) {
            Text("验证码已发送到 \(registerEmail)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            CustomTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $registerOTP,
                keyboardType: .numberPad
            )

            Button(action: handleVerifyRegisterOTP) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(authManager.isLoading ? "验证中..." : "验证")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ApocalypseTheme.primary)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(authManager.isLoading || registerOTP.count != 6)
            .opacity((authManager.isLoading || registerOTP.count != 6) ? 0.6 : 1.0)

            // 重新发送倒计时
            HStack {
                Text("没收到验证码？")
                    .font(.footnote)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                if registerCountdown > 0 {
                    Text("\(registerCountdown)秒后重发")
                        .font(.footnote)
                        .foregroundColor(ApocalypseTheme.textMuted)
                } else {
                    Button(action: handleSendRegisterOTP) {
                        Text("重新发送")
                            .font(.footnote)
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            }
        }
    }

    // 注册第三步：设置密码
    private var registerPasswordStep: some View {
        VStack(spacing: 20) {
            Text("设置登录密码")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "密码（至少6位）",
                text: $registerPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $registerPasswordConfirm
            )

            // 密码验证提示
            if !registerPassword.isEmpty && registerPassword.count < 6 {
                Text("密码至少需要6位")
                    .font(.footnote)
                    .foregroundColor(ApocalypseTheme.warning)
            }

            if !registerPasswordConfirm.isEmpty && registerPassword != registerPasswordConfirm {
                Text("两次密码不一致")
                    .font(.footnote)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            Button(action: handleCompleteRegistration) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(authManager.isLoading ? "注册中..." : "完成注册")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ApocalypseTheme.primary)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isRegisterPasswordValid)
            .opacity(isRegisterPasswordValid ? 1.0 : 0.6)
        }
    }

    // MARK: - 重置密码弹窗

    private var resetPasswordSheet: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        switch resetStep {
                        case .email:
                            resetEmailStep
                        case .otp:
                            resetOTPStep
                        case .password:
                            resetPasswordStep
                        }
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 32)
                }
            }
            .navigationTitle("找回密码")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        showResetSheet = false
                        resetToInitialState()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("关闭") {
                        showResetSheet = false
                        resetToInitialState()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            #endif
        }
    }

    // 重置密码第一步：输入邮箱
    private var resetEmailStep: some View {
        VStack(spacing: 20) {
            Text("输入注册邮箱获取验证码")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $resetEmail,
                keyboardType: .emailAddress
            )

            Button(action: handleSendResetOTP) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(authManager.isLoading ? "发送中..." : "发送验证码")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ApocalypseTheme.primary)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(authManager.isLoading || resetEmail.isEmpty)
            .opacity((authManager.isLoading || resetEmail.isEmpty) ? 0.6 : 1.0)
        }
    }

    // 重置密码第二步：输入验证码
    private var resetOTPStep: some View {
        VStack(spacing: 20) {
            Text("验证码已发送到 \(resetEmail)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            CustomTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $resetOTP,
                keyboardType: .numberPad
            )

            Button(action: handleVerifyResetOTP) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(authManager.isLoading ? "验证中..." : "验证")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ApocalypseTheme.primary)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(authManager.isLoading || resetOTP.count != 6)
            .opacity((authManager.isLoading || resetOTP.count != 6) ? 0.6 : 1.0)

            // 重新发送倒计时
            HStack {
                Text("没收到验证码？")
                    .font(.footnote)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                if resetCountdown > 0 {
                    Text("\(resetCountdown)秒后重发")
                        .font(.footnote)
                        .foregroundColor(ApocalypseTheme.textMuted)
                } else {
                    Button(action: handleSendResetOTP) {
                        Text("重新发送")
                            .font(.footnote)
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            }
        }
    }

    // 重置密码第三步：设置新密码
    private var resetPasswordStep: some View {
        VStack(spacing: 20) {
            Text("设置新密码")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "新密码（至少6位）",
                text: $resetPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $resetPasswordConfirm
            )

            // 密码验证提示
            if !resetPassword.isEmpty && resetPassword.count < 6 {
                Text("密码至少需要6位")
                    .font(.footnote)
                    .foregroundColor(ApocalypseTheme.warning)
            }

            if !resetPasswordConfirm.isEmpty && resetPassword != resetPasswordConfirm {
                Text("两次密码不一致")
                    .font(.footnote)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            Button(action: handleResetPassword) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(authManager.isLoading ? "重置中..." : "重置密码")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ApocalypseTheme.primary)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isResetPasswordValid)
            .opacity(isResetPasswordValid ? 1.0 : 0.6)
        }
    }

    // MARK: - 第三方登录

    private var thirdPartyLoginView: some View {
        VStack(spacing: 16) {
            // 分隔线
            HStack {
                Rectangle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.3))
                    .frame(height: 1)

                Text("或者使用以下方式登录")
                    .font(.footnote)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .padding(.horizontal, 8)

                Rectangle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal, 32)

            // Apple 登录按钮
            Button(action: handleAppleSignIn) {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                    Text("使用 Apple 登录")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.horizontal, 32)

            // Google 登录按钮
            Button(action: handleGoogleSignIn) {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                    Text("使用 Google 登录")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - 业务逻辑

    // 登录
    private func handleLogin() {
        Task {
            await authManager.signIn(email: loginEmail, password: loginPassword)
        }
    }

    // 发送注册验证码
    private func handleSendRegisterOTP() {
        Task {
            await authManager.sendRegisterOTP(email: registerEmail)
            if authManager.otpSent {
                registerStep = .otp
                startRegisterCountdown()
            }
        }
    }

    // 验证注册验证码
    private func handleVerifyRegisterOTP() {
        Task {
            await authManager.verifyRegisterOTP(email: registerEmail, code: registerOTP)
            // 验证成功后，onChange 会自动切换到密码步骤
        }
    }

    // 完成注册
    private func handleCompleteRegistration() {
        Task {
            await authManager.completeRegistration(password: registerPassword)
        }
    }

    // 发送重置验证码
    private func handleSendResetOTP() {
        Task {
            await authManager.sendResetOTP(email: resetEmail)
            if authManager.otpSent {
                resetStep = .otp
                startResetCountdown()
            }
        }
    }

    // 验证重置验证码
    private func handleVerifyResetOTP() {
        Task {
            await authManager.verifyResetOTP(email: resetEmail, code: resetOTP)
            if authManager.otpVerified {
                resetStep = .password
            }
        }
    }

    // 重置密码
    private func handleResetPassword() {
        Task {
            await authManager.resetPassword(newPassword: resetPassword)
            if authManager.isAuthenticated {
                showResetSheet = false
                resetToInitialState()
            }
        }
    }

    // Apple 登录
    private func handleAppleSignIn() {
        Task {
            await authManager.signInWithApple()
            // TODO: 显示提示
            showComingSoonToast()
        }
    }

    // Google 登录
    private func handleGoogleSignIn() {
        Task {
            await authManager.signInWithGoogle()
            // TODO: 显示提示
            showComingSoonToast()
        }
    }

    // MARK: - 辅助方法

    // 注册密码验证
    private var isRegisterPasswordValid: Bool {
        !authManager.isLoading &&
        registerPassword.count >= 6 &&
        registerPassword == registerPasswordConfirm
    }

    // 重置密码验证
    private var isResetPasswordValid: Bool {
        !authManager.isLoading &&
        resetPassword.count >= 6 &&
        resetPassword == resetPasswordConfirm
    }

    // 开始注册倒计时
    private func startRegisterCountdown() {
        registerCountdown = 60
        registerTimer?.invalidate()
        registerTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if registerCountdown > 0 {
                registerCountdown -= 1
            } else {
                registerTimer?.invalidate()
            }
        }
    }

    // 开始重置倒计时
    private func startResetCountdown() {
        resetCountdown = 60
        resetTimer?.invalidate()
        resetTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if resetCountdown > 0 {
                resetCountdown -= 1
            } else {
                resetTimer?.invalidate()
            }
        }
    }

    // 重置到初始状态
    private func resetToInitialState() {
        resetEmail = ""
        resetOTP = ""
        resetPassword = ""
        resetPasswordConfirm = ""
        resetStep = .email
        resetTimer?.invalidate()
        resetCountdown = 0
    }

    // 显示"即将开放"提示
    private func showComingSoonToast() {
        // TODO: 实现 Toast 提示
        print("即将开放")
    }
}

// MARK: - 自定义文本输入框

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: CustomKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .foregroundColor(ApocalypseTheme.textPrimary)
                #if os(iOS)
                .keyboardType(keyboardType.toUIKit)
                .autocapitalization(.none)
                #endif
                .disableAutocorrection(true)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - 跨平台键盘类型
enum CustomKeyboardType {
    case `default`
    case emailAddress
    case numberPad

    #if os(iOS)
    var toUIKit: UIKeyboardType {
        switch self {
        case .default: return .default
        case .emailAddress: return .emailAddress
        case .numberPad: return .numberPad
        }
    }
    #endif
}

// MARK: - 自定义密码输入框

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 20)

            SecureField(placeholder, text: $text)
                .foregroundColor(ApocalypseTheme.textPrimary)
                #if os(iOS)
                .autocapitalization(.none)
                #endif
                .disableAutocorrection(true)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    AuthView(authManager: AuthManager(supabase: supabaseClient))
}
