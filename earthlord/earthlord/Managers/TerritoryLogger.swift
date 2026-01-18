//
//  TerritoryLogger.swift
//  earthlord
//
//  领地系统日志管理器 - 单例模式 + ObservableObject
//  用于追踪圈地过程中的所有关键事件和数据
//

import Foundation
import CoreLocation
import Combine

/// 日志条目
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType

    enum LogType {
        case info      // 普通信息
        case success   // 成功操作
        case warning   // 警告
        case error     // 错误
        case debug     // 调试信息

        var emoji: String {
            switch self {
            case .info: return "📍"
            case .success: return "✅"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .debug: return "🔍"
            }
        }

        var name: String {
            switch self {
            case .info: return "INFO"
            case .success: return "SUCCESS"
            case .warning: return "WARNING"
            case .error: return "ERROR"
            case .debug: return "DEBUG"
            }
        }
    }

    /// 格式化的日志文本
    var formattedText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timeString = formatter.string(from: timestamp)
        return "\(timeString) [\(type.name)] \(message)"
    }

    /// 带 emoji 的显示文本
    var displayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeString = formatter.string(from: timestamp)
        return "\(type.emoji) \(timeString) \(message)"
    }
}

/// 领地系统日志管理器（单例）
class TerritoryLogger: ObservableObject {

    // MARK: - Singleton

    static let shared = TerritoryLogger()

    // MARK: - Published Properties

    /// 日志条目数组（最新的在前面）
    @Published var logs: [LogEntry] = []

    /// 最大日志数量
    private let maxLogCount = 1000

    // MARK: - Statistics

    /// 统计信息
    @Published var stats = Statistics()

    struct Statistics {
        var totalPoints: Int = 0           // 总点数
        var totalDistance: Double = 0      // 总距离（米）
        var closestDistanceToStart: Double = Double.infinity  // 距离起点最近的距离
        var currentSpeed: Double = 0       // 当前速度（km/h）
        var averageSpeed: Double = 0       // 平均速度（km/h）
        var trackingDuration: TimeInterval = 0  // 追踪时长（秒）
    }

    // MARK: - Private Properties

    private var trackingStartTime: Date?
    private var speedRecords: [Double] = []

    // MARK: - Initialization

    private init() {
        log("🚀 TerritoryLogger 初始化完成", type: .info)
    }

    // MARK: - Public Methods

    /// 记录日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型
    func log(_ message: String, type: LogEntry.LogType = .info) {
        let entry = LogEntry(timestamp: Date(), message: message, type: type)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 添加到数组开头
            self.logs.insert(entry, at: 0)

            // 限制日志数量
            if self.logs.count > self.maxLogCount {
                self.logs.removeLast()
            }
        }

        // 同时输出到控制台
        print("\(entry.type.emoji) \(entry.formattedText)")
    }

    /// 开始追踪
    func startTracking() {
        trackingStartTime = Date()
        stats = Statistics()
        speedRecords = []
        log("开始圈地追踪", type: .success)
    }

    /// 停止追踪
    func stopTracking() {
        if let startTime = trackingStartTime {
            stats.trackingDuration = Date().timeIntervalSince(startTime)
            log("停止圈地追踪，总时长: \(String(format: "%.0f", stats.trackingDuration))秒", type: .success)
        }
        trackingStartTime = nil
    }

    /// 更新统计信息 - 新增路径点
    func updateStats(newPoint: CLLocationCoordinate2D, totalPoints: Int) {
        stats.totalPoints = totalPoints
        log("记录路径点 #\(totalPoints): (\(String(format: "%.6f", newPoint.latitude)), \(String(format: "%.6f", newPoint.longitude)))", type: .info)
    }

    /// 更新统计信息 - 距离
    func updateDistance(distance: Double, isIncrement: Bool = true) {
        if isIncrement {
            stats.totalDistance += distance
        } else {
            stats.totalDistance = distance
        }
        log("累计距离: \(String(format: "%.1f", stats.totalDistance))m", type: .debug)
    }

    /// 更新统计信息 - 速度
    func updateSpeed(speed: Double) {
        stats.currentSpeed = speed
        speedRecords.append(speed)

        // 计算平均速度
        if !speedRecords.isEmpty {
            stats.averageSpeed = speedRecords.reduce(0, +) / Double(speedRecords.count)
        }

        if speed > 15 {
            log("当前速度: \(String(format: "%.1f", speed)) km/h", type: .warning)
        } else {
            log("当前速度: \(String(format: "%.1f", speed)) km/h", type: .debug)
        }
    }

    /// 更新统计信息 - 距离起点的距离
    func updateDistanceToStart(distance: Double) {
        if distance < stats.closestDistanceToStart {
            stats.closestDistanceToStart = distance
        }
        log("距离起点: \(String(format: "%.1f", distance))m", type: .debug)
    }

    /// 记录闭环检测结果
    func logClosureCheck(pointCount: Int, distanceToStart: Double, threshold: Double, isClosed: Bool) {
        if isClosed {
            log("🎉 闭环检测成功！点数: \(pointCount), 距离起点: \(String(format: "%.1f", distanceToStart))m", type: .success)
        } else {
            log("闭环检测: 点数 \(pointCount), 距离起点 \(String(format: "%.1f", distanceToStart))m (阈值: \(threshold)m)", type: .debug)
        }
    }

    /// 记录速度警告
    func logSpeedWarning(speed: Double, isSevere: Bool) {
        if isSevere {
            log("严重超速！速度: \(String(format: "%.1f", speed)) km/h，已停止追踪", type: .error)
        } else {
            log("速度警告: \(String(format: "%.1f", speed)) km/h", type: .warning)
        }
    }

    /// 清空日志
    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
            self?.stats = Statistics()
            self?.speedRecords.removeAll()
            self?.trackingStartTime = nil
        }
        log("日志已清空", type: .info)
    }

    /// 导出日志为文本
    func exportLogs() -> String {
        return logs.reversed().map { $0.formattedText }.joined(separator: "\n")
    }
}
