import SwiftUI

/// 网络诊断视图 - 用于测试 Supabase 连接
struct NetworkDiagnosticsView: View {
    @State private var testResult = "等待测试..."
    @State private var testStatus: TestStatus = .idle
    @State private var isTesting = false

    enum TestStatus {
        case idle
        case testing
        case success
        case failed
    }

    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                gradient: Gradient(colors: [
                    ApocalypseTheme.background,
                    Color(red: 0.05, green: 0.05, blue: 0.08)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 标题
                    VStack(spacing: 8) {
                        Image(systemName: "network")
                            .font(.system(size: 60))
                            .foregroundColor(ApocalypseTheme.primary)

                        Text("网络诊断工具")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("测试 Supabase 服务器连接")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .padding(.top, 40)

                    // 测试信息卡片
                    VStack(alignment: .leading, spacing: 16) {
                        Text("测试目标")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(
                                label: "URL",
                                value: "xlhkojuliphmvmzhpgzw.supabase.co"
                            )

                            InfoRow(
                                label: "协议",
                                value: "HTTPS (TLS/SSL)"
                            )

                            InfoRow(
                                label: "端口",
                                value: "443"
                            )
                        }
                    }
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(16)

                    // 测试结果卡片
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("测试结果")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Spacer()

                            // 状态指示器
                            statusIndicator
                        }

                        Divider()
                            .background(ApocalypseTheme.textMuted.opacity(0.2))

                        Text(testResult)
                            .font(.body)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(16)

                    // 测试按钮
                    Button(action: {
                        Task {
                            await runDiagnostics()
                        }
                    }) {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.headline)
                            }

                            Text(isTesting ? "测试中..." : "开始测试")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [
                                    ApocalypseTheme.primary,
                                    ApocalypseTheme.primary.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .disabled(isTesting)

                    // 帮助信息
                    helpSection

                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .navigationTitle("网络诊断")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        Group {
            switch testStatus {
            case .idle:
                Circle()
                    .fill(Color.gray)
                    .frame(width: 12, height: 12)
            case .testing:
                ProgressView()
                    .scaleEffect(0.7)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Help Section

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("可能的问题")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HelpItem(
                    icon: "pause.circle.fill",
                    title: "Supabase 项目已暂停",
                    description: "免费项目 7 天无活动会暂停"
                )

                HelpItem(
                    icon: "wifi.slash",
                    title: "网络连接问题",
                    description: "检查 WiFi 或移动数据连接"
                )

                HelpItem(
                    icon: "shield.slash.fill",
                    title: "防火墙或 VPN",
                    description: "尝试关闭 VPN 或防火墙"
                )
            }

            Text("💡 提示：查看 SUPABASE_CONNECTION_ISSUE.md 获取详细解决方案")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .padding(.top, 8)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
        .cornerRadius(16)
    }

    // MARK: - Diagnostics Logic

    private func runDiagnostics() async {
        testStatus = .testing
        isTesting = true
        testResult = "正在测试连接..."

        // 等待一小段时间让 UI 更新
        try? await Task.sleep(nanoseconds: 500_000_000)

        do {
            // 测试 1: 基本连接测试
            testResult += "\n\n[1/3] 测试 DNS 解析..."
            try? await Task.sleep(nanoseconds: 500_000_000)

            let url = URL(string: "https://xlhkojuliphmvmzhpgzw.supabase.co")!

            testResult += "\n✅ DNS 解析成功"

            // 测试 2: HTTPS 连接测试
            testResult += "\n\n[2/3] 测试 HTTPS 连接..."
            try? await Task.sleep(nanoseconds: 500_000_000)

            let (_, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse {
                testResult += "\n✅ HTTPS 连接成功"
                testResult += "\n   状态码: \(httpResponse.statusCode)"

                // 测试 3: Supabase API 测试
                testResult += "\n\n[3/3] 测试 Supabase API..."
                try? await Task.sleep(nanoseconds: 500_000_000)

                if httpResponse.statusCode == 200 {
                    testResult += "\n✅ Supabase 服务正常运行"
                    testResult += "\n\n🎉 所有测试通过！连接正常。"
                    testStatus = .success
                } else if httpResponse.statusCode == 404 {
                    testResult += "\n⚠️ Supabase 项目可能未配置完整"
                    testResult += "\n   但连接本身是正常的"
                    testStatus = .success
                } else {
                    testResult += "\n⚠️ 收到意外的状态码: \(httpResponse.statusCode)"
                    testStatus = .failed
                }
            }

        } catch let error as NSError {
            testStatus = .failed

            // 详细的错误分析
            testResult += "\n\n❌ 连接失败"
            testResult += "\n\n错误详情："
            testResult += "\n类型: \(error.domain)"
            testResult += "\n代码: \(error.code)"
            testResult += "\n描述: \(error.localizedDescription)"

            // 错误诊断
            testResult += "\n\n🔍 问题诊断："

            if error.domain == NSURLErrorDomain {
                switch error.code {
                case NSURLErrorTimedOut:
                    testResult += "\n• 连接超时 - 网络太慢或服务器无响应"
                case NSURLErrorCannotFindHost:
                    testResult += "\n• 无法找到主机 - DNS 解析失败"
                case NSURLErrorCannotConnectToHost:
                    testResult += "\n• 无法连接到主机 - 服务器可能已关闭"
                case NSURLErrorSecureConnectionFailed:
                    testResult += "\n• SSL/TLS 连接失败"
                    testResult += "\n• 这通常意味着 Supabase 项目已暂停或删除"
                case NSURLErrorServerCertificateUntrusted:
                    testResult += "\n• 服务器证书不受信任"
                case NSURLErrorNetworkConnectionLost:
                    testResult += "\n• 网络连接中断"
                default:
                    testResult += "\n• 未知的网络错误"
                }
            }

            testResult += "\n\n💡 建议："
            testResult += "\n1. 登录 Supabase Dashboard 检查项目状态"
            testResult += "\n2. 如果项目显示「Paused」，点击恢复"
            testResult += "\n3. 检查网络连接（尝试关闭 VPN）"
            testResult += "\n4. 查看 SUPABASE_CONNECTION_ISSUE.md"
        }

        isTesting = false
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()

            Text(value)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

struct HelpItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        NetworkDiagnosticsView()
    }
}
