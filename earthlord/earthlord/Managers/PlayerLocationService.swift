//
//  PlayerLocationService.swift
//  earthlord
//
//  玩家位置服务 - 管理玩家位置上报和附近玩家检测
//  功能：
//  1. 定期上报玩家位置到 Supabase
//  2. 查询附近在线玩家数量
//  3. 根据玩家密度计算推荐 POI 数量
//

import Foundation
import CoreLocation
import Combine
import Supabase

/// 玩家密度等级
enum PlayerDensityLevel: String, CaseIterable {
    case solo = "solo"       // 独自一人
    case low = "low"         // 低密度
    case medium = "medium"   // 中等密度
    case high = "high"       // 高密度

    /// 推荐的 POI 数量
    var recommendedPOICount: Int {
        switch self {
        case .solo: return 1
        case .low: return 3
        case .medium: return 6
        case .high: return 30
        }
    }

    /// 中文描述
    var description: String {
        switch self {
        case .solo: return "无人区域"
        case .low: return "人迹稀少"
        case .medium: return "中等人流"
        case .high: return "人员密集"
        }
    }

    /// 根据附近玩家数量计算密度等级
    static func from(count: Int) -> PlayerDensityLevel {
        switch count {
        case 0:
            return .solo
        case 1...5:
            return .low
        case 6...20:
            return .medium
        default:
            return .high
        }
    }
}

/// 位置上报触发类型
enum LocationReportTrigger: String {
    case appLaunch = "app_launch"     // App 启动
    case timer = "timer"               // 定时器
    case movement = "movement"         // 移动超过阈值
    case manual = "manual"             // 手动触发（点击探索）
    case background = "background"     // 进入后台
}

/// 玩家位置服务
@MainActor
class PlayerLocationService: NSObject, ObservableObject {

    // MARK: - 单例

    static let shared = PlayerLocationService()

    // MARK: - 发布属性

    /// 附近玩家数量
    @Published var nearbyPlayerCount: Int = 0

    /// 当前密度等级
    @Published var currentDensityLevel: PlayerDensityLevel = .solo

    /// 服务是否运行中
    @Published var isServiceRunning: Bool = false

    /// 最后上报时间
    @Published var lastReportTime: Date?

    /// 最后查询时间
    @Published var lastQueryTime: Date?

    // MARK: - 私有属性

    /// 位置管理器引用
    private let locationManager = LocationManager()

    /// 定时上报定时器
    private var reportTimer: Timer?

    /// 上次上报的位置
    private var lastReportedLocation: CLLocationCoordinate2D?

    /// 订阅集合
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 常量

    /// 定时上报间隔（秒）
    private let reportInterval: TimeInterval = 30.0

    /// 移动距离阈值（米）- 超过此距离触发上报
    private let movementThreshold: Double = 50.0

    /// 查询半径（米）
    private let queryRadius: Double = 1000.0

    /// 在线阈值（分钟）
    private let onlineThresholdMinutes: Int = 5

    // MARK: - 初始化

    private override init() {
        super.init()
        // 注册隐私设置的默认值（首次使用时默认开启）
        UserDefaults.standard.register(defaults: [
            "privacy_showLocationToPlayers": true,
            "privacy_showOnlineStatus": true
        ])
        setupLocationObserver()
    }

    // MARK: - 公开方法

    /// 启动位置服务
    func startService() {
        guard !isServiceRunning else {
            print("📍 [位置服务] 服务已在运行中")
            return
        }

        print("📍 [位置服务] ========== 启动服务 ==========")
        isServiceRunning = true

        // 启动时立即上报一次
        if let location = locationManager.userLocation {
            Task {
                await reportLocation(location, trigger: .appLaunch)
            }
        }

        // 启动定时器
        startReportTimer()

        print("📍 [位置服务] 服务已启动，上报间隔: \(reportInterval)秒")
    }

    /// 停止位置服务
    func stopService() {
        print("📍 [位置服务] ========== 停止服务 ==========")
        isServiceRunning = false
        stopReportTimer()

        // 标记离线
        Task {
            await markOffline()
        }
    }

    /// 上报当前位置
    /// - Parameters:
    ///   - location: 位置坐标
    ///   - trigger: 触发类型
    func reportLocation(_ location: CLLocationCoordinate2D, trigger: LocationReportTrigger) async {
        let showLocation = UserDefaults.standard.bool(forKey: "privacy_showLocationToPlayers")
        let showOnline = UserDefaults.standard.bool(forKey: "privacy_showOnlineStatus")

        // 如果用户关闭了位置共享，不上报位置，仅标记在线状态
        if !showLocation {
            print("📍 [位置上报] 用户已关闭位置共享，跳过上报")
            return
        }

        print("📍 [位置上报] 触发: \(trigger.rawValue)")
        print("   坐标: (\(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude)))")

        do {
            // 获取当前用户
            let session = try await supabaseClient.auth.session
            let userId = session.user.id

            // 使用 upsert 插入或更新位置
            let locationData: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "latitude": .double(location.latitude),
                "longitude": .double(location.longitude),
                "location": .string("SRID=4326;POINT(\(location.longitude) \(location.latitude))"),
                "is_online": .bool(showOnline),
                "last_seen_at": .string(ISO8601DateFormatter().string(from: Date())),
                "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]

            try await supabaseClient
                .from("player_locations")
                .upsert(locationData, onConflict: "user_id")
                .execute()

            lastReportedLocation = location
            lastReportTime = Date()

            print("✅ [位置上报] 成功")

        } catch {
            print("❌ [位置上报] 失败: \(error.localizedDescription)")
        }
    }

    /// 标记当前用户为离线
    func markOffline() async {
        print("📍 [位置服务] 标记离线...")

        do {
            let session = try await supabaseClient.auth.session
            let userId = session.user.id

            let updateData: [String: AnyJSON] = [
                "is_online": .bool(false),
                "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]

            try await supabaseClient
                .from("player_locations")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .execute()

            print("✅ [位置服务] 已标记为离线")

        } catch {
            print("❌ [位置服务] 标记离线失败: \(error.localizedDescription)")
        }
    }

    /// 查询附近在线玩家数量
    /// - Parameter center: 查询中心坐标
    /// - Returns: 附近玩家数量
    func queryNearbyPlayerCount(center: CLLocationCoordinate2D) async -> Int {
        print("🔍 [玩家查询] 查询附近 \(queryRadius)m 内的在线玩家...")
        print("   中心: (\(String(format: "%.6f", center.latitude)), \(String(format: "%.6f", center.longitude)))")

        do {
            // 构建 RPC 参数
            let params: [String: AnyJSON] = [
                "center_lat": .double(center.latitude),
                "center_lon": .double(center.longitude),
                "radius_meters": .double(queryRadius),
                "online_threshold_minutes": .integer(onlineThresholdMinutes)
            ]

            // 调用 RPC 函数
            let response: Int = try await supabaseClient
                .rpc("count_nearby_online_players", params: params)
                .execute()
                .value

            nearbyPlayerCount = response
            currentDensityLevel = PlayerDensityLevel.from(count: response)
            lastQueryTime = Date()

            print("✅ [玩家查询] 附近玩家: \(response) 人")
            print("   密度等级: \(currentDensityLevel.description) (\(currentDensityLevel.rawValue))")
            print("   推荐 POI 数: \(currentDensityLevel.recommendedPOICount)")

            return response

        } catch {
            print("❌ [玩家查询] 失败: \(error.localizedDescription)")
            // 查询失败时返回 0，使用 solo 模式
            nearbyPlayerCount = 0
            currentDensityLevel = .solo
            return 0
        }
    }

    // MARK: - 私有方法

    /// 设置位置监听
    private func setupLocationObserver() {
        locationManager.$userLocation
            .compactMap { $0 }
            .sink { [weak self] (location: CLLocationCoordinate2D) in
                guard let self = self, self.isServiceRunning else { return }

                // 检查是否移动超过阈值
                if let lastLocation = self.lastReportedLocation {
                    let distance = self.calculateDistance(from: lastLocation, to: location)
                    if distance >= self.movementThreshold {
                        print("📍 [位置服务] 移动 \(String(format: "%.0f", distance))m，触发上报")
                        Task { @MainActor in
                            await self.reportLocation(location, trigger: .movement)
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// 启动定时上报
    private func startReportTimer() {
        stopReportTimer()

        reportTimer = Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if let location = self.locationManager.userLocation {
                    await self.reportLocation(location, trigger: .timer)
                }
            }
        }

        print("📍 [位置服务] 定时器已启动，间隔: \(reportInterval)秒")
    }

    /// 停止定时上报
    private func stopReportTimer() {
        reportTimer?.invalidate()
        reportTimer = nil
        print("📍 [位置服务] 定时器已停止")
    }

    /// 计算两点之间的距离
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
}

// MARK: - App 生命周期处理

extension PlayerLocationService {

    /// App 进入后台时调用
    func handleAppDidEnterBackground() {
        print("📍 [位置服务] App 进入后台")
        Task {
            await markOffline()
        }
    }

    /// App 进入前台时调用
    func handleAppWillEnterForeground() {
        print("📍 [位置服务] App 进入前台")
        if isServiceRunning, let location = locationManager.userLocation {
            Task {
                await reportLocation(location, trigger: .appLaunch)
            }
        }
    }
}
