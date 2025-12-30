import SwiftUI
import Supabase

struct SupabaseTestView: View {
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var debugLog: String = "点击下方按钮测试 Supabase 连接..."
    @State private var isTesting: Bool = false

    enum ConnectionStatus {
        case idle
        case success
        case failed
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // 标题
                Text("Supabase 连接测试")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(.top, 40)

                // 状态图标
                ZStack {
                    Circle()
                        .fill(statusBackgroundColor)
                        .frame(width: 100, height: 100)

                    Image(systemName: statusIcon)
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 20)

                // 调试日志文本框
                ScrollView {
                    Text(debugLog)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                }
                .frame(maxHeight: 300)
                .padding(.horizontal, 20)

                Spacer()

                // 测试按钮
                Button(action: testConnection) {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isTesting ? "正在测试..." : "测试连接")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isTesting)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - 计算属性

    private var statusIcon: String {
        switch connectionStatus {
        case .idle:
            return "questionmark.circle"
        case .success:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusBackgroundColor: Color {
        switch connectionStatus {
        case .idle:
            return ApocalypseTheme.textMuted
        case .success:
            return ApocalypseTheme.success
        case .failed:
            return ApocalypseTheme.danger
        }
    }

    // MARK: - 测试连接方法

    private func testConnection() {
        isTesting = true
        connectionStatus = .idle
        debugLog = "开始测试连接...\n"
        appendLog("Supabase URL: https://xlhkojuliphmvmzhpgzw.supabase.co")
        appendLog("尝试查询不存在的表以测试连接...")

        Task {
            do {
                // 故意查询一个不存在的表来测试连接
                let _: [EmptyResponse] = try await supabaseClient
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // 如果执行到这里，说明查询成功（不应该发生）
                await MainActor.run {
                    appendLog("⚠️ 意外：表存在或返回了数据")
                    connectionStatus = .success
                    isTesting = false
                }

            } catch {
                // 分析错误信息
                await MainActor.run {
                    analyzeError(error)
                    isTesting = false
                }
            }
        }
    }

    // MARK: - 错误分析

    private func analyzeError(_ error: Error) {
        let errorDescription = error.localizedDescription
        appendLog("\n收到错误响应:")
        appendLog(errorDescription)

        // 检查是否包含 Postgres REST 错误代码
        if errorDescription.contains("PGRST") {
            appendLog("\n✅ 连接成功（服务器已响应）")
            appendLog("检测到 Postgres REST API 错误码")
            connectionStatus = .success
        }
        // 检查是否包含表不存在的错误
        else if errorDescription.contains("Could not find the table") ||
                errorDescription.contains("relation") && errorDescription.contains("does not exist") {
            appendLog("\n✅ 连接成功（服务器已响应）")
            appendLog("确认：表不存在，说明已成功连接到数据库")
            connectionStatus = .success
        }
        // 检查网络或 URL 错误
        else if errorDescription.contains("hostname") ||
                errorDescription.contains("URL") ||
                errorDescription.contains("NSURLErrorDomain") {
            appendLog("\n❌ 连接失败：URL 错误或无网络")
            appendLog("请检查网络连接和 Supabase URL 配置")
            connectionStatus = .failed
        }
        // 其他错误
        else {
            appendLog("\n❓ 未知错误:")
            appendLog(errorDescription)
            connectionStatus = .failed
        }
    }

    // MARK: - 辅助方法

    private func appendLog(_ message: String) {
        debugLog += "\n" + message
    }
}

// 空响应结构，用于接收查询结果
struct EmptyResponse: Codable {}

#Preview {
    SupabaseTestView()
}
