//
//  TerritoryTestView.swift
//  earthlord
//
//  领地测试视图 - 显示圈地过程的详细日志和统计信息
//  注意：不套 NavigationStack，由外部控制
//

import SwiftUI

struct TerritoryTestView: View {
    @StateObject private var logger = TerritoryLogger.shared
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            // 统计信息面板
            statsPanel
                .padding()
                .background(ApocalypseTheme.cardBackground)

            Divider()

            // 日志列表
            logsList
        }
        .navigationTitle("领地测试")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        autoScroll.toggle()
                    }) {
                        Label(
                            autoScroll ? "关闭自动滚动" : "开启自动滚动",
                            systemImage: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle"
                        )
                    }

                    Button(action: {
                        exportLogs()
                    }) {
                        Label("导出日志", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button(role: .destructive, action: {
                        logger.clear()
                    }) {
                        Label("清空日志", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: - Subviews

    /// 统计信息面板
    private var statsPanel: some View {
        VStack(spacing: 12) {
            Text("实时统计")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                statCard(
                    title: "路径点数",
                    value: "\(logger.stats.totalPoints)",
                    icon: "mappin.circle.fill",
                    color: .blue
                )

                statCard(
                    title: "累计距离",
                    value: String(format: "%.1fm", logger.stats.totalDistance),
                    icon: "ruler.fill",
                    color: .green
                )

                statCard(
                    title: "当前速度",
                    value: String(format: "%.1f km/h", logger.stats.currentSpeed),
                    icon: "speedometer",
                    color: logger.stats.currentSpeed > 15 ? .orange : .cyan
                )

                statCard(
                    title: "平均速度",
                    value: String(format: "%.1f km/h", logger.stats.averageSpeed),
                    icon: "gauge.medium",
                    color: .purple
                )

                statCard(
                    title: "距离起点",
                    value: logger.stats.closestDistanceToStart == Double.infinity
                        ? "N/A"
                        : String(format: "%.1fm", logger.stats.closestDistanceToStart),
                    icon: "location.circle.fill",
                    color: .orange
                )

                statCard(
                    title: "追踪时长",
                    value: formatDuration(logger.stats.trackingDuration),
                    icon: "clock.fill",
                    color: .indigo
                )
            }
        }
    }

    /// 统计卡片
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(ApocalypseTheme.background)
        .cornerRadius(8)
    }

    /// 日志列表
    private var logsList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(logger.logs) { log in
                    logRow(log)
                        .id(log.id)
                }
            }
            .listStyle(.plain)
            .onChange(of: logger.logs.count) { _ in
                if autoScroll, let firstLog = logger.logs.first {
                    withAnimation {
                        proxy.scrollTo(firstLog.id, anchor: .top)
                    }
                }
            }
        }
    }

    /// 日志行
    private func logRow(_ log: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Emoji 图标
            Text(log.type.emoji)
                .font(.system(size: 16))

            // 时间戳
            Text(timeString(from: log.timestamp))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 60, alignment: .leading)

            // 消息内容
            Text(log.message)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(colorForLogType(log.type))
                .lineLimit(nil)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helper Methods

    /// 格式化时间
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    /// 日志类型对应的颜色
    private func colorForLogType(_ type: LogEntry.LogType) -> Color {
        switch type {
        case .info: return ApocalypseTheme.textPrimary
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .debug: return ApocalypseTheme.textSecondary
        }
    }

    /// 格式化时长
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration == 0 {
            return "0s"
        }

        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    /// 导出日志
    private func exportLogs() {
        let logsText = logger.exportLogs()
        let activityVC = UIActivityViewController(
            activityItems: [logsText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

#Preview {
    NavigationStack {
        TerritoryTestView()
    }
}
