//
//  LocationManager.swift
//  earthlord
//
//  GPS 定位管理器 - 负责获取用户位置和管理定位权限
//  扩展支持路径追踪功能（圈地模式）
//

import Foundation
import CoreLocation
import Combine  // ⚠️ @Published 需要这个框架
import Network  // 网络状态监控

/// GPS 定位管理器
class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    /// 是否正在定位中
    @Published var isLocating: Bool = false

    // MARK: - 路径追踪属性

    /// 是否正在圈地追踪中
    @Published var isTracking: Bool = false

    /// 路径坐标数组（GCJ-02 坐标，用于地图显示）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发地图刷新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否已闭合
    @Published var isPathClosed: Bool = false

    /// 当前位置距离起点的距离（米）- 用于UI提示
    @Published var distanceToStartPoint: Double?

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    // MARK: - 验证状态属性

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算得到的领地面积（平方米）
    @Published var calculatedArea: Double = 0

    // MARK: - 行走距离统计属性

    /// 总行走距离（米）
    @Published var totalWalkDistance: Double = 0

    /// 今日行走距离（米）
    @Published var todayWalkDistance: Double = 0

    /// 上次记录的日期（用于判断是否需要重置今日距离）
    private var lastRecordDate: Date {
        get {
            if let date = UserDefaults.standard.object(forKey: "lastWalkRecordDate") as? Date {
                return date
            }
            return Date()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastWalkRecordDate")
        }
    }

    /// 当前位置（Timer 采点用）
    var currentLocation: CLLocation?

    /// 上次行走位置（用于日常行走距离计算）
    private var lastWalkingLocation: CLLocation?

    /// 上次行走时间戳（用于日常行走速度检测）
    private var lastWalkingTimestamp: Date?

    /// 路径采点定时器
    private var pathUpdateTimer: Timer?

    /// 日志管理器
    private let logger = TerritoryLogger.shared

    /// 是否运行在模拟器上
    private var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// 最小采点距离（米）- 模拟器中降低要求以便测试
    private var minRecordDistance: Double {
        if isRunningOnSimulator {
            return 0.5  // 模拟器中降低到 0.5 米（GPS 可能有微小漂移）
        } else {
            return 3.0  // 真机上保持 3 米
        }
    }

    /// 采点间隔（秒）
    private let recordInterval: TimeInterval = 2.0

    /// 闭环距离阈值（米）
    private let closureDistanceThreshold: Double = 20.0  // 考虑GPS精度，放宽到20米

    // MARK: - 验证常量

    /// 最少路径点数（闭环检测前提条件）
    private var minimumPathPoints: Int {
        return 10  // 原游戏设计：至少 10 个路径点
    }

    /// 最小行走距离（米）
    private var minimumTotalDistance: Double {
        return 50.0  // 原游戏设计：至少行走 50 米
    }

    /// 最小领地面积（平方米）
    private var minimumEnclosedArea: Double {
        return 100.0  // 原游戏设计：至少 100 平方米
    }

    /// 上次记录位置的时间戳（用于速度计算）- 使用 GPS 时间戳，不是系统时间
    private var lastLocationTimestamp: Date?

    // MARK: - Private Properties

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

    /// 网络状态监控器
    private let networkMonitor = NWPathMonitor()

    /// 网络监控队列
    private let networkQueue = DispatchQueue(label: "com.earthlord.network")

    /// 当前网络类型（用于检测切换）
    private var currentNetworkType: NWInterface.InterfaceType?

    // MARK: - Computed Properties

    /// 是否已授权定位
    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// 是否被用户拒绝
    var isDenied: Bool {
        authorizationStatus == .denied
    }

    /// 是否尚未决定（首次请求）
    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    // MARK: - Initialization

    override init() {
        // 获取当前授权状态
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 10  // 移动10米才更新位置

        // ⚠️ 关键配置：确保在网络切换时继续定位
        locationManager.allowsBackgroundLocationUpdates = false  // 不需要后台定位
        locationManager.pausesLocationUpdatesAutomatically = false  // 不自动暂停
        locationManager.activityType = .fitness  // 健身模式（步行、跑步等）

        print("📍 LocationManager 初始化完成")
        print("   当前授权状态: \(authorizationStatusDescription)")
        print("   游戏设计参数:")
        print("   - 最少点数: \(minimumPathPoints)")
        print("   - 最小距离: \(minimumTotalDistance)m")
        print("   - 最小面积: \(minimumEnclosedArea)m²")
        print("   - 闭环阈值: \(closureDistanceThreshold)m")
        print("   - 采点距离: \(minRecordDistance)m")

        // 加载行走距离数据
        loadWalkingStats()

        // 启动网络状态监控
        setupNetworkMonitoring()
    }

    // MARK: - Public Methods

    /// 请求定位权限
    func requestPermission() {
        print("📍 请求定位权限...")
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始更新位置
    func startUpdatingLocation() {
        guard isAuthorized else {
            print("⚠️ 未授权定位，无法开始")
            locationError = "请先授权定位权限"
            return
        }

        print("📍 开始获取位置...")
        isLocating = true
        locationError = nil
        locationManager.startUpdatingLocation()

        // 模拟器回退方案：如果 3 秒内没有收到位置更新，使用默认模拟位置
        #if targetEnvironment(simulator)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            // 只有在没有收到真实位置时才使用模拟位置
            if self.userLocation == nil {
                print("📍 [模拟器] 未收到位置更新，使用默认模拟位置")
                self.useSimulatorFallbackLocation()
            }
        }
        #endif
    }

    #if targetEnvironment(simulator)
    /// 模拟器回退位置（北京天安门广场）
    private func useSimulatorFallbackLocation() {
        // 默认位置：北京天安门广场
        let simulatedCoordinate = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
        let simulatedLocation = CLLocation(
            coordinate: simulatedCoordinate,
            altitude: 50,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: Date()
        )

        self.currentLocation = simulatedLocation
        self.userLocation = simulatedCoordinate
        self.locationError = nil

        print("📍 [模拟器] 使用模拟位置: (\(simulatedCoordinate.latitude), \(simulatedCoordinate.longitude))")
        print("💡 提示: 在 Xcode 中可通过 Debug > Simulate Location 设置自定义位置")
    }
    #endif

    /// 停止更新位置
    func stopUpdatingLocation() {
        print("📍 停止获取位置")
        isLocating = false
        locationManager.stopUpdatingLocation()
    }

    /// 请求一次性位置更新
    func requestLocation() {
        guard isAuthorized else {
            print("⚠️ 未授权定位，无法请求位置")
            locationError = "请先授权定位权限"
            return
        }

        print("📍 请求一次性位置...")
        locationError = nil
        locationManager.requestLocation()
    }

    /// 重新居中到用户位置（返回当前位置）
    func getCurrentLocation() -> CLLocationCoordinate2D? {
        return userLocation
    }

    // MARK: - 路径追踪方法

    /// 开始路径追踪（圈地模式）
    func startPathTracking() {
        guard isAuthorized else {
            print("⚠️ 未授权定位，无法开始圈地")
            locationError = "请先授权定位权限"
            return
        }

        print("🏃 开始圈地追踪...")
        logger.startTracking()

        // 重置状态
        pathCoordinates = []
        lastRawLocation = nil
        isPathClosed = false
        isTracking = true
        pathUpdateVersion += 1
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil
        consecutiveOverspeedCount = 0
        consecutiveSevereOverspeedCount = 0
        distanceToStartPoint = nil  // 重置距离起点的距离

        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // ⚠️ 圈地模式：降低距离过滤器，确保更频繁接收位置更新
        // 这对网络切换场景很重要
        locationManager.distanceFilter = kCLDistanceFilterNone  // 接收所有位置更新
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation  // 最高精度（导航级别）
        print("📍 已切换到高频定位模式（无距离过滤）")

        // 确保定位已开启
        startUpdatingLocation()

        // 如果有当前位置，立即记录第一个点
        if let location = currentLocation {
            recordPathPoint(from: location)
            lastRawLocation = location
            print("✅ 立即记录起始点")

            // 延迟1秒后再记录一个点，确保至少有2个点可以显示轨迹
            // 注意：即使位置相同也记录，目的是让用户能立即看到轨迹
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self, self.isTracking else { return }
                if let location = self.currentLocation {
                    self.recordPathPoint(from: location)
                    print("✅ 记录第二个初始点（确保轨迹可见）")
                }
            }
        }

        // 启动定时器，每2秒检查一次
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: recordInterval, repeats: true) { [weak self] _ in
            self?.checkAndRecordPoint()
        }

        print("⏱️ 采点定时器已启动，间隔 \(recordInterval) 秒")
    }

    /// 停止路径追踪并重置所有状态
    func stopPathTracking() {
        print("🛑 停止圈地追踪")
        logger.stopTracking()

        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 重置追踪状态
        isTracking = false

        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // 重置路径状态
        pathCoordinates = []
        isPathClosed = false
        pathUpdateVersion += 1

        // 重置速度相关状态
        speedWarning = nil
        isOverSpeed = false
        lastRawLocation = nil
        lastLocationTimestamp = nil
        consecutiveOverspeedCount = 0
        consecutiveSevereOverspeedCount = 0

        // 恢复正常的距离过滤器
        locationManager.distanceFilter = 10  // 恢复为10米过滤
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        print("📍 已恢复正常定位模式（10米过滤）")
        print("✅ 所有圈地状态已重置")
    }

    /// 清空路径
    func clearPath() {
        print("🗑️ 清空路径")
        pathCoordinates = []
        isPathClosed = false
        pathUpdateVersion += 1
    }

    /// 上一个原始位置（WGS-84，用于距离计算）
    private var lastRawLocation: CLLocation?

    /// 检查并记录路径点
    /// ⚠️ 关键：先检查距离，再检查速度！顺序不能反！
    private func checkAndRecordPoint() {
        print("\n━━━━━━ 📍 检查采点开始 ━━━━━━")

        guard isTracking else {
            print("⚠️ 检查采点：未在追踪状态")
            return
        }

        guard let location = currentLocation else {
            print("⚠️ 检查采点：无当前位置")
            logger.log("警告：定时器触发但无位置更新，可能 GPS 信号丢失", type: .warning)
            return
        }

        // 显示位置时间戳，用于调试
        let locationAge = Date().timeIntervalSince(location.timestamp)
        print("📍 当前位置: (\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude)))")
        print("📅 位置时间戳: \(location.timestamp)")
        print("⏱️ 位置年龄: \(String(format: "%.1f", locationAge))秒")

        // 如果位置太旧（超过 10 秒），警告但继续处理
        if locationAge > 10 {
            print("⚠️ 位置数据较旧（\(String(format: "%.1f", locationAge))秒前），可能GPS信号不稳定")
            logger.log("位置数据较旧（\(String(format: "%.1f", locationAge))秒前），GPS 信号可能不稳定", type: .warning)
        }

        // 步骤1：先检查距离（过滤 GPS 漂移，距离不够就直接返回）
        if let lastLocation = lastRawLocation {
            let distance = location.distance(from: lastLocation)
            print("📏 步骤1 - 距离检查:")
            print("   上次位置: (\(String(format: "%.6f", lastLocation.coordinate.latitude)), \(String(format: "%.6f", lastLocation.coordinate.longitude)))")
            print("   本次位置: (\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude)))")
            print("   距离: \(String(format: "%.1f", distance))m")
            print("   要求: ≥ \(String(format: "%.1f", minRecordDistance))m")

            // 距离不够，不进行速度检测，直接返回
            guard distance >= minRecordDistance else {
                print("❌ 距离不足，跳过采点")
                print("━━━━━━ 检查采点结束（距离不足）━━━━━━\n")
                return
            }

            print("✅ 距离检查通过")
        } else {
            print("📏 步骤1 - 距离检查: 首次记录，无需距离检查")
        }

        // 步骤2：再检查速度（只对真实移动进行检测）
        print("🚗 步骤2 - 速度检查:")
        guard validateMovementSpeed(newLocation: location) else {
            print("❌ 严重超速，不记录该点")
            print("━━━━━━ 检查采点结束（超速）━━━━━━\n")
            return
        }
        print("✅ 速度检查通过")

        // 步骤3：记录新点
        print("💾 步骤3 - 记录新点:")
        recordPathPoint(from: location)
        lastRawLocation = location
        // ⚠️ 关键：使用 GPS 时间戳，不是系统时间
        lastLocationTimestamp = location.timestamp
        print("   已更新 lastRawLocation")
        print("   已更新 lastLocationTimestamp: \(location.timestamp)")

        // 步骤4：检测闭环
        print("🔍 步骤4 - 检测闭环")
        checkPathClosure()

        print("━━━━━━ 检查采点结束（成功）━━━━━━\n")
    }

    /// 记录路径点（WGS-84 → GCJ-02 转换）
    private func recordPathPoint(from location: CLLocation) {
        // 转换为 GCJ-02 坐标（中国地图使用）
        let gcjCoord = CoordinateConverter.wgs84ToGcj02(location.coordinate)

        // 计算距上一个点的距离
        var distanceFromLast: Double = 0
        if let lastLocation = lastRawLocation {
            distanceFromLast = location.distance(from: lastLocation)
            // 累加到总距离
            logger.updateDistance(distance: distanceFromLast, isIncrement: true)
            // 更新行走距离统计
            updateWalkingDistance(distance: distanceFromLast)
        }

        pathCoordinates.append(gcjCoord)
        pathUpdateVersion += 1

        // 打印日志（格式参考用户提供的日志）
        if pathCoordinates.count == 1 {
            print("📍 记录路径点 #\(pathCoordinates.count): (\(String(format: "%.6f", gcjCoord.latitude)), \(String(format: "%.6f", gcjCoord.longitude)))")
        } else {
            print("📍 记录第 \(pathCoordinates.count) 个点，距上点 \(Int(distanceFromLast))m")
        }

        // 记录到日志
        logger.updateStats(newPoint: gcjCoord, totalPoints: pathCoordinates.count)
    }

    /// 连续超速计数（用于防止 GPS 跳变误报）
    private var consecutiveOverspeedCount: Int = 0

    /// 触发警告所需的连续超速次数
    private let overspeedThreshold: Int = 3

    /// 触发停止所需的连续严重超速次数
    private let severeOverspeedThreshold: Int = 2

    /// 连续严重超速计数
    private var consecutiveSevereOverspeedCount: Int = 0

    /// 验证移动速度（防止作弊）
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示可以记录该点，false 表示严重超速不记录
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 首次记录，没有上一个点，直接通过
        guard let lastLocation = lastRawLocation,
              let lastTimestamp = lastLocationTimestamp else {
            print("   ℹ️ 首次记录，跳过速度检测")
            return true
        }

        print("   📊 速度检测详情:")

        // 过滤 GPS 精度差的位置（精度 > 50m 时跳过速度检测，避免位置跳变误报）
        if newLocation.horizontalAccuracy > 50 || newLocation.horizontalAccuracy < 0 {
            print("      ⚠️ GPS 精度差（\(String(format: "%.1f", newLocation.horizontalAccuracy))m），跳过速度检测")
            return true
        }

        // 计算距离（米）
        let distance = newLocation.distance(from: lastLocation)
        print("      距离: \(String(format: "%.2f", distance))m")

        // ⚠️ 关键：计算时间差，使用 GPS 时间戳，不是系统时间
        let timeInterval = newLocation.timestamp.timeIntervalSince(lastTimestamp)
        print("      时间差: \(String(format: "%.2f", timeInterval))秒")

        // 防止除零错误、负数时间、以及过短时间间隔（< 1秒的读数不可靠）
        guard timeInterval > 1.0 else {
            print("      ⚠️ 时间间隔过短（\(String(format: "%.2f", timeInterval))秒），跳过速度检测")
            return true
        }

        // 计算速度（km/h）
        let speedMetersPerSecond = distance / timeInterval
        let speedKmPerHour = speedMetersPerSecond * 3.6
        print("      速度: \(String(format: "%.1f", speedKmPerHour)) km/h")

        // 记录速度到日志
        logger.updateSpeed(speed: speedKmPerHour)

        // 判断速度范围
        print("      判断速度范围:")

        // 速度 > 30 km/h：严重超速
        if speedKmPerHour > 30 {
            consecutiveSevereOverspeedCount += 1
            consecutiveOverspeedCount += 1
            print("      ⚠️ 严重超速 (\(consecutiveSevereOverspeedCount)/\(severeOverspeedThreshold))")

            // 需要连续多次严重超速才停止追踪（防止 GPS 单次跳变）
            if consecutiveSevereOverspeedCount >= severeOverspeedThreshold {
                print("      ❌ 连续严重超速，停止追踪")
                speedWarning = "速度过快 (\(String(format: "%.0f", speedKmPerHour)) km/h)，已自动停止圈地"
                isOverSpeed = true
                logger.logSpeedWarning(speed: speedKmPerHour, isSevere: true)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.stopPathTracking()
                }
                return false
            }

            // 未达到阈值，跳过此点但不停止
            return false
        }

        // 速度 > 15 km/h：轻度超速
        if speedKmPerHour > 15 {
            consecutiveOverspeedCount += 1
            consecutiveSevereOverspeedCount = 0  // 非严重超速，重置严重计数
            print("      ⚠️ 轻度超速 (\(consecutiveOverspeedCount)/\(overspeedThreshold))")

            // 需要连续多次超速才显示警告
            if consecutiveOverspeedCount >= overspeedThreshold {
                speedWarning = "移动速度较快 (\(String(format: "%.0f", speedKmPerHour)) km/h)，请保持步行速度"
                isOverSpeed = true
                logger.logSpeedWarning(speed: speedKmPerHour, isSevere: false)

                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.speedWarning = nil
                    self?.isOverSpeed = false
                }
            }

            return true
        }

        // 速度正常，重置所有超速计数
        print("      ✅ 速度正常 (≤ 15 km/h)")
        consecutiveOverspeedCount = 0
        consecutiveSevereOverspeedCount = 0
        speedWarning = nil
        isOverSpeed = false
        return true
    }

    /// 检测路径是否闭合
    private func checkPathClosure() {
        // 已经闭合，跳过检测
        guard !isPathClosed else { return }

        // 点数不足，无法检测
        guard pathCoordinates.count >= minimumPathPoints else {
            print("🔍 闭环检测: 点数不足 (\(pathCoordinates.count)/\(minimumPathPoints))")
            return
        }

        // 获取起点和当前点
        guard let startPoint = pathCoordinates.first,
              let currentPoint = pathCoordinates.last else {
            return
        }

        // 计算当前点到起点的距离（使用 WGS-84 坐标计算）
        let startLocation = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
        let distanceToStart = currentLocation.distance(from: startLocation)

        // 更新距离（用于UI显示）
        distanceToStartPoint = distanceToStart

        print("🔍 闭环检测: 距离起点 \(String(format: "%.1f", distanceToStart))m (阈值: \(closureDistanceThreshold)m)")

        // 记录距离到起点的日志
        logger.updateDistanceToStart(distance: distanceToStart)

        // 距离小于阈值，闭环成功
        let isClosed = distanceToStart <= closureDistanceThreshold
        if isClosed {
            isPathClosed = true
            pathUpdateVersion += 1
            print("✅ 🎉 闭环检测成功！路径已闭合，共 \(pathCoordinates.count) 个点")
            print("   起点: (\(String(format: "%.6f", startPoint.latitude)), \(String(format: "%.6f", startPoint.longitude)))")
            print("   终点: (\(String(format: "%.6f", currentPoint.latitude)), \(String(format: "%.6f", currentPoint.longitude)))")
            print("   距离: \(String(format: "%.1f", distanceToStart))m")
        }

        // 记录闭环检测结果到日志
        logger.logClosureCheck(
            pointCount: pathCoordinates.count,
            distanceToStart: distanceToStart,
            threshold: closureDistanceThreshold,
            isClosed: isClosed
        )

        // 闭环成功后，自动触发验证
        if isClosed {
            print("🔍 开始执行领地验证...")
            let result = validateTerritory()
            territoryValidationPassed = result.isValid
            territoryValidationError = result.errorMessage
            print("🔍 验证结果: \(result.isValid ? "通过 ✅" : "失败 ❌") - \(result.errorMessage ?? "无错误")")
        }
    }

    // MARK: - 距离与面积计算

    /// 计算路径总距离
    /// - Returns: 总距离（米）
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<pathCoordinates.count - 1 {
            let current = pathCoordinates[i]
            let next = pathCoordinates[i + 1]

            let loc1 = CLLocation(latitude: current.latitude, longitude: current.longitude)
            let loc2 = CLLocation(latitude: next.latitude, longitude: next.longitude)

            totalDistance += loc1.distance(from: loc2)
        }

        return totalDistance
    }

    /// 计算多边形面积（使用墨卡托投影 + 鞋带公式）
    /// - Returns: 面积（平方米）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        logger.log("━━━━━━ 面积计算调试开始 ━━━━━━", type: .debug)

        // 找到多边形的中心点
        let centerLat = pathCoordinates.map { $0.latitude }.reduce(0, +) / Double(pathCoordinates.count)
        let centerLon = pathCoordinates.map { $0.longitude }.reduce(0, +) / Double(pathCoordinates.count)

        logger.log("步骤1: 点数=\(pathCoordinates.count), 中心点=(\(String(format: "%.6f", centerLat)), \(String(format: "%.6f", centerLon)))", type: .debug)

        // 打印原始坐标（前3个和后3个点）
        for i in 0..<min(3, pathCoordinates.count) {
            let coord = pathCoordinates[i]
            logger.log("原始坐标[\(i)]: lat=\(String(format: "%.6f", coord.latitude)), lon=\(String(format: "%.6f", coord.longitude))", type: .debug)
        }
        if pathCoordinates.count > 3 {
            let lastCoord = pathCoordinates[pathCoordinates.count - 1]
            logger.log("原始坐标[\(pathCoordinates.count - 1)]: lat=\(String(format: "%.6f", lastCoord.latitude)), lon=\(String(format: "%.6f", lastCoord.longitude))", type: .debug)
        }

        // 在中心点处的米/度转换系数
        // 1度纬度 ≈ 111,320 米（这个值在全球各地都接近）
        // 1度经度 = 111,320 * cos(纬度) 米（随纬度变化）
        let metersPerDegreeLat = 111320.0
        let metersPerDegreeLon = 111320.0 * cos(centerLat * .pi / 180.0)

        logger.log("步骤2: 转换系数 - 纬度: 1°=\(String(format: "%.2f", metersPerDegreeLat))m, 经度: 1°=\(String(format: "%.2f", metersPerDegreeLon))m", type: .debug)

        // 将经纬度坐标转换为米制平面坐标（相对于中心点）
        let projectedPoints = pathCoordinates.map { coord -> (x: Double, y: Double) in
            let x = (coord.longitude - centerLon) * metersPerDegreeLon
            let y = (coord.latitude - centerLat) * metersPerDegreeLat
            return (x, y)
        }

        // 打印投影坐标（前3个）
        for i in 0..<min(3, projectedPoints.count) {
            let p = projectedPoints[i]
            logger.log("投影坐标[\(i)]: x=\(String(format: "%.2f", p.x))m, y=\(String(format: "%.2f", p.y))m", type: .debug)
        }

        // 计算投影坐标的范围，用于估算多边形大小
        let xCoords = projectedPoints.map { $0.x }
        let yCoords = projectedPoints.map { $0.y }
        let minX = xCoords.min() ?? 0
        let maxX = xCoords.max() ?? 0
        let minY = yCoords.min() ?? 0
        let maxY = yCoords.max() ?? 0
        let width = maxX - minX
        let height = maxY - minY
        let boundingBoxArea = width * height

        logger.log("步骤3: X范围=[\(String(format: "%.2f", minX)), \(String(format: "%.2f", maxX))], 宽度=\(String(format: "%.2f", width))m", type: .debug)
        logger.log("步骤3: Y范围=[\(String(format: "%.2f", minY)), \(String(format: "%.2f", maxY))], 高度=\(String(format: "%.2f", height))m", type: .debug)
        logger.log("步骤3: 矩形包络面积估算=\(String(format: "%.2f", boundingBoxArea))m²", type: .info)

        // 使用鞋带公式（Shoelace Formula）计算平面多边形面积
        var area: Double = 0.0

        for i in 0..<projectedPoints.count {
            let current = projectedPoints[i]
            let next = projectedPoints[(i + 1) % projectedPoints.count]
            let term = current.x * next.y - next.x * current.y
            area += term

            // 只记录前3项
            if i < 3 {
                logger.log("鞋带项[\(i)→\((i + 1) % projectedPoints.count)]: \(String(format: "%.2f", current.x))*\(String(format: "%.2f", next.y)) - \(String(format: "%.2f", next.x))*\(String(format: "%.2f", current.y)) = \(String(format: "%.2f", term))", type: .debug)
            }
        }

        logger.log("步骤4: 鞋带公式累加和=\(String(format: "%.2f", area)), 除以2=\(String(format: "%.2f", area / 2.0))", type: .debug)

        let finalArea = abs(area / 2.0)

        logger.log("━━━━━━ 面积计算结果: \(String(format: "%.2f", finalArea))m² (包络估算: \(String(format: "%.2f", boundingBoxArea))m²) ━━━━━━", type: .info)

        // 如果计算面积远小于包络面积，输出警告
        if boundingBoxArea > 0 && finalArea < boundingBoxArea * 0.1 {
            logger.log("⚠️ 警告: 计算面积(\(String(format: "%.2f", finalArea))m²)远小于包络面积(\(String(format: "%.2f", boundingBoxArea))m²)的10%，可能存在问题！", type: .warning)
        }

        return finalArea
    }

    // MARK: - 自相交检测

    /// 判断两条线段是否相交（使用 CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1的起点
    ///   - p2: 线段1的终点
    ///   - p3: 线段2的起点
    ///   - p4: 线段2的终点
    /// - Returns: true 表示相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                    p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        /// CCW 辅助函数：判断三点是否逆时针排列
        /// - 叉积 > 0 表示逆时针
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            // ⚠️ 坐标映射：longitude = X轴，latitude = Y轴
            let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                               (B.latitude - A.latitude) * (C.longitude - A.longitude)
            return crossProduct > 0
        }

        // 判断两线段是否相交
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) &&
               ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检测路径是否存在自相交
    /// - Returns: true 表示存在自相交（画了"8"字形）
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量
        let skipHeadCount = 2
        let skipTailCount = 2

        for i in 0..<segmentCount {
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 跳过首尾附近线段的比较
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount

                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        return false
    }

    // MARK: - 综合验证

    /// 综合验证领地是否有效
    /// - Returns: (验证结果, 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        print("🔍 validateTerritory() 开始执行")

        // 添加分隔符，让日志更醒目
        TerritoryLogger.shared.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━", type: .info)
        TerritoryLogger.shared.log("开始领地验证", type: .info)
        print("📝 记录日志: 开始领地验证")

        // 1. 点数检查
        print("🔍 步骤1: 点数检查 - 当前点数: \(pathCoordinates.count), 要求: \(minimumPathPoints)")
        if pathCoordinates.count < minimumPathPoints {
            let error = "点数不足: \(pathCoordinates.count)个点 (需≥\(minimumPathPoints)个)"
            print("❌ 点数检查失败: \(error)")
            TerritoryLogger.shared.log("点数检查: \(error)", type: .error)
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }
        let pointCheckMessage = "点数检查: \(pathCoordinates.count)个点 ✓"
        print("✅ \(pointCheckMessage)")
        TerritoryLogger.shared.log(pointCheckMessage, type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        print("🔍 步骤2: 距离检查 - 总距离: \(String(format: "%.0f", totalDistance))m, 要求: \(String(format: "%.0f", minimumTotalDistance))m")
        if totalDistance < minimumTotalDistance {
            let error = "距离不足: \(String(format: "%.0f", totalDistance))m (需≥\(String(format: "%.0f", minimumTotalDistance))m)"
            print("❌ 距离检查失败: \(error)")
            TerritoryLogger.shared.log("距离检查: \(error)", type: .error)
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }
        let distanceCheckMessage = "距离检查: \(String(format: "%.0f", totalDistance))m ✓"
        print("✅ \(distanceCheckMessage)")
        TerritoryLogger.shared.log(distanceCheckMessage, type: .info)

        // 3. 面积计算（提前计算，让失败时也能显示）
        let area = calculatePolygonArea()
        calculatedArea = area  // 保存计算得到的面积
        print("📐 面积计算: \(String(format: "%.0f", area))m²")
        TerritoryLogger.shared.log("面积计算: \(String(format: "%.0f", area))m²", type: .info)

        // 4. 自交检测
        print("🔍 步骤3: 自交检测")
        let hasSelfIntersection = hasPathSelfIntersection()
        print("🔍 自交检测结果: \(hasSelfIntersection ? "有自交 ❌" : "无自交 ✅")")
        if hasSelfIntersection {
            let error = "轨迹自相交(8字形)，请重新圈地。已圈面积: \(String(format: "%.0f", area))m²"
            print("❌ 自交检测失败: \(error)")
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }
        // 注意：hasPathSelfIntersection() 内部已经记录了 "自交检测: 无交叉 ✓" 的日志

        // 5. 面积检查
        print("🔍 步骤4: 面积检查 - 面积: \(String(format: "%.0f", area))m², 要求: \(String(format: "%.0f", minimumEnclosedArea))m²")
        if area < minimumEnclosedArea {
            let error = "面积不足: \(String(format: "%.0f", area))m² (需≥\(String(format: "%.0f", minimumEnclosedArea))m²)"
            print("❌ 面积检查失败: \(error)")
            TerritoryLogger.shared.log("面积检查: \(error)", type: .error)
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }
        let areaCheckMessage = "面积检查: \(String(format: "%.0f", area))m² ✓"
        print("✅ \(areaCheckMessage)")
        TerritoryLogger.shared.log(areaCheckMessage, type: .info)

        // 验证通过
        let successMessage = "圈地成功！领地面积: \(String(format: "%.0f", area))m²"
        print("🎉 \(successMessage)")
        TerritoryLogger.shared.log(successMessage, type: .success)
        TerritoryLogger.shared.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━", type: .info)
        return (true, nil)
    }

    // MARK: - Walking Distance Tracking

    /// 加载行走距离统计
    private func loadWalkingStats() {
        // 加载总距离
        totalWalkDistance = UserDefaults.standard.double(forKey: "totalWalkDistance")

        // 检查是否需要重置今日距离
        let today = Calendar.current.startOfDay(for: Date())
        let lastDay = Calendar.current.startOfDay(for: lastRecordDate)

        if today > lastDay {
            // 新的一天，重置今日距离
            todayWalkDistance = 0
            UserDefaults.standard.set(0, forKey: "todayWalkDistance")
            lastRecordDate = Date()
            print("📊 新的一天，今日行走距离已重置")
        } else {
            // 同一天，加载今日距离
            todayWalkDistance = UserDefaults.standard.double(forKey: "todayWalkDistance")
        }

        print("📊 行走统计已加载:")
        print("   - 总距离: \(String(format: "%.2f", totalWalkDistance))m")
        print("   - 今日距离: \(String(format: "%.2f", todayWalkDistance))m")
    }

    /// 保存行走距离统计
    private func saveWalkingStats() {
        UserDefaults.standard.set(totalWalkDistance, forKey: "totalWalkDistance")
        UserDefaults.standard.set(todayWalkDistance, forKey: "todayWalkDistance")
        lastRecordDate = Date()
    }

    /// 更新行走距离
    /// - Parameter distance: 新增的距离（米）
    func updateWalkingDistance(distance: Double) {
        totalWalkDistance += distance
        todayWalkDistance += distance
        saveWalkingStats()

        print("📊 行走距离已更新: +\(String(format: "%.2f", distance))m")
        print("   - 总距离: \(String(format: "%.2f", totalWalkDistance))m")
        print("   - 今日距离: \(String(format: "%.2f", todayWalkDistance))m")

        // 通知奖励管理器更新
        Task { @MainActor in
            WalkingRewardManager.shared.updateWalkingDistance(
                totalDistance: totalWalkDistance,
                todayDistance: todayWalkDistance
            )
        }
    }

    /// 追踪日常行走距离（位置更新时调用）
    /// - Parameter newLocation: 新位置
    private func trackDailyWalkingDistance(newLocation: CLLocation) {
        // 精度检查：只统计精度良好的位置
        guard newLocation.horizontalAccuracy >= 0 && newLocation.horizontalAccuracy <= 50 else {
            print("📊 [行走统计] 跳过：GPS精度不足 (\(String(format: "%.1f", newLocation.horizontalAccuracy))m)")
            return
        }

        // 如果有上一个位置，计算距离和速度
        if let lastLocation = lastWalkingLocation,
           let lastTimestamp = lastWalkingTimestamp {

            let distance = newLocation.distance(from: lastLocation)
            let timeInterval = newLocation.timestamp.timeIntervalSince(lastTimestamp)

            print("📊 [行走统计] 位置变化:")
            print("   - 距离: \(String(format: "%.2f", distance))m")
            print("   - 时间间隔: \(String(format: "%.2f", timeInterval))s")

            // 防止时间异常
            guard timeInterval > 0.1 else {
                print("📊 [行走统计] 跳过：时间间隔异常")
                return
            }

            // 计算速度
            let speedMetersPerSecond = distance / timeInterval
            let speedKmPerHour = speedMetersPerSecond * 3.6

            print("   - 速度: \(String(format: "%.2f", speedKmPerHour)) km/h")

            // 速度检查：只统计合理的行走速度（≤ 30 km/h）
            guard speedKmPerHour <= 30 else {
                print("📊 [行走统计] 跳过：速度过快 (\(String(format: "%.2f", speedKmPerHour)) km/h > 30 km/h)")
                // 仍然更新位置，以便下次计算
                lastWalkingLocation = newLocation
                lastWalkingTimestamp = newLocation.timestamp
                return
            }

            // 距离过滤：忽略太小的移动（GPS 漂移）
            guard distance >= 3.0 else {
                print("📊 [行走统计] 跳过：距离太小 (\(String(format: "%.2f", distance))m < 3m，可能是GPS漂移)")
                return
            }

            // ✅ 通过所有检查，累加距离
            print("📊 [行走统计] ✅ 记录行走: +\(String(format: "%.2f", distance))m")
            updateWalkingDistance(distance: distance)
        } else {
            print("📊 [行走统计] 初始化：记录首次位置")
        }

        // 更新上次位置和时间
        lastWalkingLocation = newLocation
        lastWalkingTimestamp = newLocation.timestamp
    }

    // MARK: - Private Helpers

    /// 授权状态描述
    private var authorizationStatusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "未决定"
        case .restricted:
            return "受限制"
        case .denied:
            return "已拒绝"
        case .authorizedAlways:
            return "始终允许"
        case .authorizedWhenInUse:
            return "使用时允许"
        @unknown default:
            return "未知"
        }
    }

    // MARK: - Network Monitoring

    /// 设置网络状态监控
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.handleNetworkPathUpdate(path)
            }
        }

        networkMonitor.start(queue: networkQueue)
        print("📡 网络监控已启动")
    }

    /// 处理网络状态更新
    private func handleNetworkPathUpdate(_ path: NWPath) {
        let isConnected = path.status == .satisfied
        let newNetworkType = path.availableInterfaces.first?.type

        // 获取网络类型描述
        let networkTypeDescription: String
        if let type = newNetworkType {
            switch type {
            case .wifi:
                networkTypeDescription = "WiFi"
            case .cellular:
                networkTypeDescription = "蜂窝数据"
            case .wiredEthernet:
                networkTypeDescription = "有线网络"
            case .loopback:
                networkTypeDescription = "回环"
            case .other:
                networkTypeDescription = "其他"
            @unknown default:
                networkTypeDescription = "未知"
            }
        } else {
            networkTypeDescription = "无网络"
        }

        print("📡 网络状态: \(isConnected ? "已连接" : "未连接") - \(networkTypeDescription)")

        // 检测网络切换
        if let currentType = currentNetworkType, let newType = newNetworkType, currentType != newType {
            let oldTypeDesc: String
            switch currentType {
            case .wifi:
                oldTypeDesc = "WiFi"
            case .cellular:
                oldTypeDesc = "蜂窝数据"
            default:
                oldTypeDesc = "其他网络"
            }

            let message = "网络已切换: \(oldTypeDesc) → \(networkTypeDescription)"
            print("⚠️ \(message)")

            // 如果正在圈地，记录网络切换警告并重启定位
            if isTracking {
                logger.log(message, type: .warning)
                logger.log("正在重启 GPS 定位以确保连续性...", type: .info)

                // ⚠️ 关键修复：网络切换时重启定位服务
                // 这确保了 GPS 不会因为网络切换而中断
                print("🔄 网络切换检测到，重启定位服务...")
                self.restartLocationUpdates()

                // 延迟 0.5 秒后确认
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    self.logger.log("GPS 定位已重启，继续记录路径", type: .success)
                    print("✅ GPS 定位已重启")
                }
            }
        }

        // 更新当前网络类型
        currentNetworkType = newNetworkType

        // 如果网络完全断开
        if !isConnected {
            print("⚠️ 网络已断开")
            if isTracking {
                logger.log("网络已断开，正在重启 GPS 定位...", type: .warning)

                // ⚠️ 网络断开时也重启定位，确保纯 GPS 模式
                print("🔄 网络断开检测到，切换到纯 GPS 模式...")
                restartLocationUpdates()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    self.logger.log("已切换到纯 GPS 模式（不依赖网络）", type: .success)
                }
            }
        }
    }

    /// 重启定位服务（用于网络切换场景）
    private func restartLocationUpdates() {
        print("🔄 重启定位服务...")

        // 保存当前配置
        let currentAccuracy = locationManager.desiredAccuracy
        let currentFilter = locationManager.distanceFilter

        // 停止并立即重启
        locationManager.stopUpdatingLocation()

        // 延迟 0.1 秒后重启（给系统时间处理停止请求）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }

            // 恢复配置
            self.locationManager.desiredAccuracy = currentAccuracy
            self.locationManager.distanceFilter = currentFilter

            // 重启定位
            self.locationManager.startUpdatingLocation()
            print("✅ 定位服务已重启，精度: \(currentAccuracy), 过滤: \(currentFilter)m")
        }
    }

    /// 停止网络监控（析构时调用）
    deinit {
        networkMonitor.cancel()
        print("📡 网络监控已停止")
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态变化回调
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let oldStatus = self.authorizationStatus
            self.authorizationStatus = manager.authorizationStatus

            print("📍 授权状态变化: \(self.authorizationStatusDescription)")

            // 如果刚获得授权，自动开始定位
            if self.isAuthorized && oldStatus == .notDetermined {
                print("   ✅ 用户授权成功，开始定位")
                self.startUpdatingLocation()
            }

            // 如果被拒绝，设置错误信息
            if self.isDenied {
                self.locationError = "定位权限被拒绝，请在设置中开启"
            }
        }
    }

    /// 位置更新回调
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 更新当前位置（Timer 采点需要）
            self.currentLocation = location
            self.userLocation = location.coordinate
            self.locationError = nil

            // 检查 GPS 精度
            let accuracy = location.horizontalAccuracy
            let accuracyDescription: String
            if accuracy < 0 {
                accuracyDescription = "无效"
            } else if accuracy <= 10 {
                accuracyDescription = "优秀"
            } else if accuracy <= 30 {
                accuracyDescription = "良好"
            } else if accuracy <= 100 {
                accuracyDescription = "一般"
            } else {
                accuracyDescription = "较差"
            }

            print("📍 位置更新: (\(location.coordinate.latitude), \(location.coordinate.longitude)) - 精度: \(String(format: "%.1f", accuracy))m (\(accuracyDescription))")

            // 如果正在圈地且精度较差，记录警告
            if self.isTracking && accuracy > 50 {
                self.logger.log("GPS 精度较差: \(String(format: "%.1f", accuracy))m，可能影响圈地准确性", type: .warning)
            }

            // 📊 日常行走距离统计（不仅限于圈地时）
            self.trackDailyWalkingDistance(newLocation: location)
        }
    }

    /// 定位失败回调
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isLocating = false

            // 处理不同类型的错误
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self?.locationError = "定位权限被拒绝"
                case .locationUnknown:
                    self?.locationError = "无法确定当前位置"
                case .network:
                    self?.locationError = "网络错误，无法定位"
                default:
                    self?.locationError = "定位失败: \(error.localizedDescription)"
                }
            } else {
                self?.locationError = "定位失败: \(error.localizedDescription)"
            }

            print("❌ 定位失败: \(error.localizedDescription)")
        }
    }
}
