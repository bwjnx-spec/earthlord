//
//  ExplorationManager.swift
//  earthlord
//
//  探索管理器 - 处理 POI 发现、物品收集、探索统计
//  功能：
//  1. 基于 GPS 位置检测附近 POI
//  2. 计算与 POI 的距离
//  3. 处理 POI 搜寻和物品掉落
//  4. 管理玩家背包和探索统计
//  5. 与 Supabase 同步数据
//  6. 搜索附近真实 POI（MKLocalSearch API）
//  7. POI 距离监测和搜刮触发
//

import Foundation
import CoreLocation
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// 探索管理器
@MainActor
class ExplorationManager: NSObject, ObservableObject {

    // MARK: - 单例

    static let shared = ExplorationManager()

    // MARK: - 发布属性

    /// 附近的 POI 列表
    @Published var nearbyPOIs: [POI] = []

    /// 玩家背包物品
    @Published var inventoryItems: [InventoryItem] = []

    /// 探索统计
    @Published var explorationStats: ExplorationStats = ExplorationStats(
        totalWalkDistance: 0.0,
        todayWalkDistance: 0.0,
        walkDistanceRank: 0,
        totalExplorationTime: 0,
        totalPOIsDiscovered: 0,
        totalItemsCollected: 0
    )

    /// 当前玩家位置
    @Published var currentLocation: CLLocationCoordinate2D?

    /// 加载状态
    @Published var isLoading = false

    /// 错误消息
    @Published var errorMessage: String?

    /// 是否正在探索中
    @Published var isExploring = false

    /// 当前可搜刮的 POI（进入 50m 范围内时设置）
    @Published var currentLootablePOI: POI?

    /// 是否显示搜刮提示
    @Published var showLootPrompt = false

    /// POI 版本号（用于触发地图更新）
    @Published var poisVersion: Int = 0

    /// 当前 POI 来源
    @Published var currentPOISource: POISource = .procedural

    // MARK: - 私有属性

    private var cancellables = Set<AnyCancellable>()
    private let locationManager = LocationManager()

    /// POI 搜索服务
    private let poiSearchService = POISearchService.shared

    /// 玩家位置服务
    private let playerLocationService = PlayerLocationService.shared

    /// POI 发现距离阈值（米）
    private let discoveryRadius: Double = 50.0

    /// POI 搜寻距离阈值（米）- 搜刮触发距离（临时放宽到100米用于测试）
    private let searchRadius: Double = 100.0

    /// POI 搜索半径（米）
    private let poiSearchRadius: Double = 1000.0

    /// 【测试模式】是否自动触发最近POI的提示（即使超出范围）
    /// 设为 true 用于测试，生产环境设为 false
    private let testModeAutoTriggerClosestPOI = true

    /// 【测试模式】自动触发的最大距离（米）
    private let testModeMaxTriggerDistance: Double = 1000.0

    /// 背包最大容量
    private let maxBackpackCapacity = 100

    /// 距离检测定时器（备用方案）
    private var proximityTimer: Timer?

    /// 距离检测间隔（秒）- 缩短到1秒提高响应速度
    private let proximityCheckInterval: TimeInterval = 1.0

    /// 已提示过的 POI（避免重复提示）
    private var promptedPOIs: Set<UUID> = []

    /// 地理围栏管理器
    private var geofenceLocationManager: CLLocationManager?

    /// 地理围栏触发距离（米）
    private let geofenceRadius: Double = 50.0

    /// 上次搜索POI的位置
    private var lastPOISearchLocation: CLLocationCoordinate2D?

    /// POI自动刷新距离阈值（米）- 用户移动超过此距离后自动重新搜索
    private let poiRefreshDistanceThreshold: Double = 500.0

    // MARK: - 持久化 Key

    private let inventoryStorageKey = "earthlord_inventory_items"
    private let statsStorageKey = "earthlord_exploration_stats"

    // MARK: - 初始化

    private override init() {
        super.init()
        setupLocationObserver()
        setupGeofenceManager()
        loadSavedData()  // 优先加载本地保存的数据
    }

    /// 设置地理围栏管理器
    private func setupGeofenceManager() {
        geofenceLocationManager = CLLocationManager()
        geofenceLocationManager?.delegate = self
        geofenceLocationManager?.desiredAccuracy = kCLLocationAccuracyBest
        print("🎯 [地理围栏] 管理器已初始化")
    }

    // MARK: - 位置监听

    /// 设置位置监听
    private func setupLocationObserver() {
        locationManager.$userLocation
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                guard let self = self else { return }
                self.currentLocation = coordinate

                // 如果正在探索，检查是否需要刷新POI
                if self.isExploring {
                    self.checkAndRefreshPOIs(at: coordinate)
                }
            }
            .store(in: &cancellables)
    }

    /// 检查是否需要刷新POI（当用户移动超过阈值时）
    private func checkAndRefreshPOIs(at currentLocation: CLLocationCoordinate2D) {
        guard let lastLocation = lastPOISearchLocation else {
            // 首次，不刷新
            return
        }

        // 计算距离上次搜索位置的距离
        let lastCLLocation = CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude)
        let currentCLLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let distance = currentCLLocation.distance(from: lastCLLocation)

        // 如果移动超过阈值，自动刷新POI
        if distance >= poiRefreshDistanceThreshold {
            print("📍 [POI自动刷新] 用户移动了 \(String(format: "%.0f", distance))m，重新搜索POI")
            Task {
                await searchNearbyRealPOIs()
            }
        }
    }

    // MARK: - 真实 POI 搜索

    /// 搜索附近的真实 POI
    /// 使用 MKLocalSearch API 搜索附近 1km 内的真实地点
    /// 基于玩家密度动态调整 POI 数量
    func searchNearbyRealPOIs() async {
        print("🔍 [诊断-EM] searchNearbyRealPOIs 被调用")
        print("🔍 [诊断-EM] currentLocation = \(currentLocation?.latitude ?? 0), \(currentLocation?.longitude ?? 0)")

        guard let currentLocation = currentLocation else {
            print("⚠️ [探索] 无当前位置，无法搜索 POI")
            errorMessage = "无法获取当前位置"
            return
        }
        print("🔍 [诊断-EM] 通过 currentLocation 检查")

        print("🔍 [探索] 开始搜索附近 \(poiSearchRadius)m 内的真实 POI...")
        isLoading = true
        isExploring = true
        errorMessage = nil
        print("🔍 [诊断-EM] isLoading 设置为 true")

        do {
            // 步骤1：上报当前位置
            print("📍 [探索] 步骤1：上报玩家位置...")
            await playerLocationService.reportLocation(currentLocation, trigger: .manual)

            // 步骤2：查询附近玩家数量
            print("👥 [探索] 步骤2：查询附近玩家...")
            let playerCount = await playerLocationService.queryNearbyPlayerCount(center: currentLocation)
            let densityLevel = PlayerDensityLevel.from(count: playerCount)
            let targetPOICount = densityLevel.recommendedPOICount

            print("👥 [探索] 附近玩家: \(playerCount) 人")
            print("👥 [探索] 密度等级: \(densityLevel.description) (\(densityLevel.rawValue))")
            print("👥 [探索] 目标 POI 数: \(targetPOICount)")

            // 步骤3：调用 POI 搜索服务（传入目标数量）
            let (pois, source) = try await poiSearchService.searchNearbyPOIs(
                center: currentLocation,
                radius: poiSearchRadius,
                maxCount: targetPOICount
            )

            print("✅ [探索] 搜索完成，找到 \(pois.count) 个 POI，来源: \(source.rawValue)")

            // 更新 POI 列表和来源
            nearbyPOIs = pois
            currentPOISource = source
            poisVersion += 1  // 触发地图更新

            // 记录搜索位置
            lastPOISearchLocation = currentLocation

            print("📍 [探索] POI 列表:")
            for (index, poi) in nearbyPOIs.enumerated() {
                print("   \(index + 1). \(poi.name) - (\(String(format: "%.6f", poi.location.latitude)), \(String(format: "%.6f", poi.location.longitude))) [\(poi.source.rawValue)]")
            }

            // 启动地理围栏监控（主要方案）
            setupPOIGeofences()

            // 同时启动定时器轮询（备用方案，确保兼容性）
            startPOIProximityMonitoring()

            // 【关键】立即执行一次距离检测，不等待定时器
            print("🎯 [探索] 立即执行首次距离检测...")
            checkPOIProximity()

            // 更新统计
            explorationStats.totalPOIsDiscovered += pois.count
            saveStats()

        } catch {
            print("❌ [探索] POI 搜索失败: \(error.localizedDescription)")
            errorMessage = "搜索失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 设置 POI 地理围栏
    /// 使用 iOS 地理围栏功能监控 POI 接近（最多 20 个）
    func setupPOIGeofences() {
        guard let manager = geofenceLocationManager else {
            print("⚠️ [地理围栏] 管理器未初始化")
            return
        }

        // 移除所有旧围栏
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        print("🎯 [地理围栏] 已清除旧围栏，共 \(manager.monitoredRegions.count) 个")

        // 为每个 POI 创建地理围栏（iOS 限制最多 20 个）
        let poisToMonitor = nearbyPOIs.prefix(20)
        var geofenceCount = 0

        for poi in poisToMonitor {
            // 跳过已搜刮的 POI
            guard poi.status != .looted else { continue }

            let region = CLCircularRegion(
                center: poi.coordinate,
                radius: geofenceRadius,
                identifier: poi.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false

            manager.startMonitoring(for: region)
            geofenceCount += 1

            print("🎯 [地理围栏] 添加围栏: \(poi.name) (半径: \(geofenceRadius)m)")
        }

        print("✅ [地理围栏] 共设置 \(geofenceCount) 个围栏")
    }

    /// 停止所有地理围栏监控
    func stopPOIGeofences() {
        guard let manager = geofenceLocationManager else { return }

        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        print("🛑 [地理围栏] 已停止所有围栏监控")
    }

    /// 启动 POI 距离监测（定时器轮询，备用方案）
    /// 每 2 秒检测一次玩家与 POI 的距离
    func startPOIProximityMonitoring() {
        // 先停止已有的定时器
        stopPOIProximityMonitoring()

        print("🎯 [距离监测-定时器] 启动，间隔: \(proximityCheckInterval)秒")

        proximityTimer = Timer.scheduledTimer(withTimeInterval: proximityCheckInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.checkPOIProximity()
            }
        }
    }

    /// 停止 POI 距离监测（定时器轮询）
    func stopPOIProximityMonitoring() {
        proximityTimer?.invalidate()
        proximityTimer = nil
        print("🛑 [距离监测-定时器] 已停止")
    }

    /// 检测 POI 距离并触发搜刮提示（定时器轮询方案）
    func checkPOIProximity() {
        guard let currentLocation = currentLocation else {
            print("🎯 [距离监测] ❌ 无当前位置，跳过检测")
            return
        }

        // 每5次检测输出一次详细日志，避免日志过多
        let shouldPrintDetails = (poisVersion % 5 == 0)

        if shouldPrintDetails {
            print("🔍 [距离检测] 用户位置: (\(String(format: "%.6f", currentLocation.latitude)), \(String(format: "%.6f", currentLocation.longitude)))")
            print("🔍 [距离检测] 检查 \(nearbyPOIs.count) 个POI，搜刮半径: \(searchRadius)m")
        }

        var closestPOI: POI?
        var closestDistance: Double = Double.infinity

        // 更新所有 POI 的距离
        for i in nearbyPOIs.indices {
            let distance = calculateDistance(
                from: currentLocation,
                to: nearbyPOIs[i].location
            )
            nearbyPOIs[i].distance = distance

            // 记录最近的 POI
            if distance < closestDistance {
                closestDistance = distance
                closestPOI = nearbyPOIs[i]
            }

            // 打印每个POI的距离（用于调试）
            if shouldPrintDetails, let distance = nearbyPOIs[i].distance {
                let inRange = distance <= searchRadius ? "✅" : "  "
                print("  \(inRange) \(nearbyPOIs[i].name): \(Int(distance))m, 状态: \(nearbyPOIs[i].status)")
            }
        }

        // 输出最近的 POI 信息
        if let closest = closestPOI {
            print("🎯 [距离监测] 最近POI: \(closest.name) = \(Int(closestDistance))m (需要 ≤ \(Int(searchRadius))m)")
        }

        // 检查是否有 POI 在搜刮范围内
        var foundPOIInRange = false
        for poi in nearbyPOIs {
            guard let distance = poi.distance else { continue }

            // 进入搜刮范围内
            if distance <= searchRadius {
                // 检查是否已提示过
                if !promptedPOIs.contains(poi.id) {
                    // 检查是否可搜刮（未被搜空）
                    if poi.status != .looted {
                        print("🎯🎯🎯 [距离监测-定时器] ✅ 进入 POI 范围: \(poi.name) (\(String(format: "%.0f", distance))m / \(String(format: "%.0f", searchRadius))m)")

                        // 设置当前可搜刮的 POI
                        currentLootablePOI = poi
                        showLootPrompt = true
                        promptedPOIs.insert(poi.id)
                        foundPOIInRange = true

                        // 触发震动反馈
                        triggerProximityFeedback()

                        break  // 一次只提示一个
                    } else {
                        print("  ⚠️ \(poi.name) 已被搜刮，跳过")
                    }
                }
            }
        }

        // 【测试模式】如果没有范围内的POI，自动触发最近的未搜刮POI
        if testModeAutoTriggerClosestPOI && !foundPOIInRange {
            if let closest = closestPOI,
               closestDistance <= testModeMaxTriggerDistance,
               closest.status != .looted,
               !promptedPOIs.contains(closest.id) {
                print("🧪🧪🧪 [测试模式] 自动触发最近POI: \(closest.name) (距离: \(Int(closestDistance))m)")

                // 设置当前可搜刮的 POI
                currentLootablePOI = closest
                showLootPrompt = true
                promptedPOIs.insert(closest.id)

                // 触发震动反馈
                triggerProximityFeedback()
            }
        }

        // 触发 POI 版本更新（用于地图刷新距离显示）
        poisVersion += 1
    }

    /// 触发接近提醒震动
    private func triggerProximityFeedback() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }

    /// 结束探索
    func stopExploration() {
        print("🛑 [探索] 结束探索")
        isExploring = false
        stopPOIProximityMonitoring()
        stopPOIGeofences()
        currentLootablePOI = nil
        showLootPrompt = false
        promptedPOIs.removeAll()
    }

    /// 重置已提示的 POI（允许再次提示）
    func resetPromptedPOIs() {
        promptedPOIs.removeAll()
    }

    /// 关闭搜刮提示
    func dismissLootPrompt() {
        showLootPrompt = false
        currentLootablePOI = nil
    }

    // MARK: - POI 发现

    /// 检查附近的 POI（使用已有数据更新距离）
    func checkNearbyPOIs() async {
        guard let currentLocation = currentLocation else { return }

        // 如果没有 POI 数据，使用 mock 数据
        if nearbyPOIs.isEmpty {
            nearbyPOIs = MockExplorationData.mockPOIs
        }

        // 计算距离并筛选附近的 POI
        nearbyPOIs = nearbyPOIs.map { poi in
            var updatedPOI = poi
            let distance = calculateDistance(
                from: currentLocation,
                to: poi.location
            )
            updatedPOI.distance = distance

            // 自动发现在发现半径内的 POI
            if distance <= discoveryRadius && poi.status == .undiscovered {
                updatedPOI.status = .discovered
                Task {
                    await markPOIAsDiscovered(poiId: poi.id)
                }
            }

            return updatedPOI
        }
        .filter { $0.distance != nil && $0.distance! <= 5000 } // 只显示 5km 内的 POI
        .sorted { ($0.distance ?? Double.infinity) < ($1.distance ?? Double.infinity) }

        poisVersion += 1  // 触发地图更新
    }

    /// 计算两点之间的距离（米）
    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    /// 标记 POI 为已发现
    func markPOIAsDiscovered(poiId: UUID) async {
        // TODO: 更新 Supabase
        if let index = nearbyPOIs.firstIndex(where: { $0.id == poiId }) {
            nearbyPOIs[index].status = .discovered
            explorationStats.totalPOIsDiscovered += 1
            saveStats()
        }
    }

    /// 手动标记 POI 为已发现
    func manuallyMarkDiscovered(poiId: UUID) async {
        await markPOIAsDiscovered(poiId: poiId)
    }

    /// 标记 POI 为无物资
    func markPOIAsNoLoot(poiId: UUID) async {
        // TODO: 更新 Supabase
        if let index = nearbyPOIs.firstIndex(where: { $0.id == poiId }) {
            nearbyPOIs[index].status = .looted
            nearbyPOIs[index].availableLoot = []
        }
    }

    // MARK: - POI 搜寻

    /// 搜寻 POI
    /// - Parameters:
    ///   - poiId: POI ID
    /// - Returns: 搜寻结果（包含获得的物品）
    func searchPOI(poiId: UUID) async throws -> ExplorationResult {
        guard currentLocation != nil else {
            throw ExplorationError.locationUnavailable
        }

        guard let poiIndex = nearbyPOIs.firstIndex(where: { $0.id == poiId }) else {
            throw ExplorationError.poiNotFound
        }

        let poi = nearbyPOIs[poiIndex]

        // 检查距离（50米内可搜刮）
        guard let distance = poi.distance, distance <= searchRadius else {
            throw ExplorationError.tooFarAway(distance: poi.distance ?? 0)
        }

        // 检查状态
        guard poi.status != .looted else {
            throw ExplorationError.alreadyLooted
        }

        // 检查背包容量
        let currentCapacity = inventoryItems.reduce(0) { $0 + $1.quantity }
        guard currentCapacity < maxBackpackCapacity else {
            throw ExplorationError.backpackFull
        }

        // 生成掉落物品（使用 AI 生成）
        let collectedItems = await generateLoot(for: poi)

        // 添加到背包
        for item in collectedItems {
            addItemToInventory(item: item)
        }

        // 更新 POI 状态
        nearbyPOIs[poiIndex].status = .looted
        nearbyPOIs[poiIndex].availableLoot = []

        // 更新统计
        explorationStats.totalItemsCollected += collectedItems.count

        // 保存统计数据
        saveStats()

        // 触发 POI 版本更新
        poisVersion += 1

        // 关闭搜刮提示
        dismissLootPrompt()

        print("✅ [搜刮] 搜刮成功: \(poi.name)，获得 \(collectedItems.count) 件物品")

        // 创建搜寻结果
        let result = ExplorationResult(
            id: UUID().uuidString,
            poiId: poi.id.uuidString,
            poiName: poi.name,
            timestamp: Date(),
            itemsCollected: collectedItems,
            experienceGained: calculateExperience(for: collectedItems)
        )

        return result
    }

    /// 生成 POI 掉落物品（使用 AI 生成）
    /// - Parameter poi: 目标 POI
    /// - Returns: 生成的物品列表
    private func generateLoot(for poi: POI) async -> [InventoryItem] {
        print("🎲 [掉落] 开始为 \(poi.name) 生成掉落物品...")

        // 使用 AI 物品生成器
        let aiGenerator = AIItemGenerator.shared
        let items = await aiGenerator.generateItems(for: poi)

        print("🎲 [掉落] 生成完成，共 \(items.count) 个物品")
        return items
    }

    /// 生成本地降级物品（备用，当直接调用时使用）
    private func generateLocalLoot(for poi: POI) -> [InventoryItem] {
        var loot: [InventoryItem] = []

        // 基于 POI 可用物资列表生成掉落
        for lootItemId in poi.availableLoot {
            // 50% 掉落率
            if Double.random(in: 0...1) > 0.5 {
                continue
            }

            // 随机数量（1-3）
            let quantity = Int.random(in: 1...3)

            // 随机品质
            let quality = ItemQuality.allCases.randomElement()

            let item = InventoryItem(
                id: UUID(),
                definitionId: lootItemId,
                quantity: quantity,
                quality: quality,
                obtainedAt: Date(),
                obtainedFrom: poi.name,
                isAIGenerated: false,
                aiName: nil,
                aiStory: nil,
                aiCategory: nil,
                aiRarity: nil
            )

            loot.append(item)
        }

        return loot
    }

    /// 计算经验值
    private func calculateExperience(for items: [InventoryItem]) -> Int {
        var exp = 0

        for item in items {
            if let definition = MockExplorationData.getItemDefinition(by: item.definitionId) {
                switch definition.rarity {
                case .common:
                    exp += 10
                case .uncommon:
                    exp += 25
                case .rare:
                    exp += 50
                case .epic:
                    exp += 100
                case .legendary:
                    exp += 250
                }
            }
        }

        return exp
    }

    // MARK: - 背包管理

    /// 添加物品到背包
    func addItemToInventory(item: InventoryItem) {
        // 检查是否已存在相同物品（可堆叠）
        if let existingIndex = inventoryItems.firstIndex(where: {
            $0.definitionId == item.definitionId && $0.quality == item.quality
        }) {
            // 堆叠
            inventoryItems[existingIndex].quantity += item.quantity
        } else {
            // 新物品
            inventoryItems.append(item)
        }

        // 保存到本地
        saveInventory()

        // TODO: 同步到 Supabase
    }

    /// 使用物品
    func useItem(inventoryItemId: UUID) async throws {
        guard let index = inventoryItems.firstIndex(where: { $0.id == inventoryItemId }) else {
            throw ExplorationError.itemNotFound
        }

        let item = inventoryItems[index]

        guard let definition = MockExplorationData.getItemDefinition(by: item.definitionId) else {
            throw ExplorationError.itemDefinitionNotFound
        }

        // TODO: 实现物品使用效果
        print("使用物品: \(definition.name)")

        // 减少数量
        if item.quantity > 1 {
            inventoryItems[index].quantity -= 1
        } else {
            inventoryItems.remove(at: index)
        }

        // 保存到本地
        saveInventory()

        // TODO: 同步到 Supabase
    }

    /// 丢弃物品
    func discardItem(inventoryItemId: UUID, quantity: Int) async throws {
        guard let index = inventoryItems.firstIndex(where: { $0.id == inventoryItemId }) else {
            throw ExplorationError.itemNotFound
        }

        let item = inventoryItems[index]

        guard quantity <= item.quantity else {
            throw ExplorationError.insufficientQuantity
        }

        if quantity >= item.quantity {
            inventoryItems.remove(at: index)
        } else {
            inventoryItems[index].quantity -= quantity
        }

        // 保存到本地
        saveInventory()

        // TODO: 同步到 Supabase
    }

    // MARK: - 数据加载

    /// 加载玩家数据（从 Supabase）
    func loadPlayerData() async {
        isLoading = true
        errorMessage = nil

        // TODO: 实现 Supabase 数据加载
        // 1. 加载背包物品
        // 2. 加载探索统计
        // 3. 加载已发现的 POI

        // 暂时从本地加载
        loadSavedData()

        isLoading = false
    }

    /// 加载本地保存的数据（优先），如果没有则用 mock 数据
    private func loadSavedData() {
        // 尝试加载背包数据
        if let inventoryData = UserDefaults.standard.data(forKey: inventoryStorageKey),
           let savedItems = try? JSONDecoder().decode([InventoryItemCodable].self, from: inventoryData) {
            inventoryItems = savedItems.map { $0.toInventoryItem() }
            print("📦 [持久化] 从本地加载背包数据，共 \(inventoryItems.count) 种物品")
        } else {
            // 没有保存的数据，使用 mock 数据
            inventoryItems = MockExplorationData.mockInventoryItems
            print("📦 [持久化] 无本地数据，使用 mock 背包数据")
        }

        // 尝试加载统计数据
        if let statsData = UserDefaults.standard.data(forKey: statsStorageKey),
           let savedStats = try? JSONDecoder().decode(ExplorationStatsCodable.self, from: statsData) {
            explorationStats = savedStats.toExplorationStats()
            print("📊 [持久化] 从本地加载统计数据")
        } else {
            print("📊 [持久化] 无本地统计数据，使用默认值")
        }

        // POI 数据暂时使用 mock（后续可从 Supabase 加载）
        nearbyPOIs = MockExplorationData.mockPOIs

        Task {
            await checkNearbyPOIs()
        }
    }

    /// 保存背包数据到本地
    private func saveInventory() {
        let codableItems = inventoryItems.map { InventoryItemCodable(from: $0) }
        if let data = try? JSONEncoder().encode(codableItems) {
            UserDefaults.standard.set(data, forKey: inventoryStorageKey)
            print("💾 [持久化] 背包数据已保存，共 \(inventoryItems.count) 种物品")
        } else {
            print("❌ [持久化] 背包数据保存失败")
        }
    }

    /// 保存统计数据到本地
    private func saveStats() {
        let codableStats = ExplorationStatsCodable(from: explorationStats)
        if let data = try? JSONEncoder().encode(codableStats) {
            UserDefaults.standard.set(data, forKey: statsStorageKey)
            print("💾 [持久化] 统计数据已保存")
        } else {
            print("❌ [持久化] 统计数据保存失败")
        }
    }

    /// 重置数据（用于测试）
    func resetData() {
        inventoryItems.removeAll()
        nearbyPOIs.removeAll()
        explorationStats = ExplorationStats(
            totalWalkDistance: 0.0,
            todayWalkDistance: 0.0,
            walkDistanceRank: 0,
            totalExplorationTime: 0,
            totalPOIsDiscovered: 0,
            totalItemsCollected: 0
        )

        // 清除本地存储
        UserDefaults.standard.removeObject(forKey: inventoryStorageKey)
        UserDefaults.standard.removeObject(forKey: statsStorageKey)
        print("🗑️ [持久化] 已清除本地存储数据")

        // 重新加载 mock 数据
        inventoryItems = MockExplorationData.mockInventoryItems
        nearbyPOIs = MockExplorationData.mockPOIs

        Task {
            await checkNearbyPOIs()
        }
    }
}

// MARK: - Codable 包装类型（用于持久化）

/// 背包物品的 Codable 包装
private struct InventoryItemCodable: Codable {
    let id: UUID
    let definitionId: String
    var quantity: Int
    var qualityRaw: String?
    let obtainedAt: Date
    let obtainedFrom: String?

    // AI 生成相关字段
    var isAIGenerated: Bool
    var aiName: String?
    var aiStory: String?
    var aiCategory: String?
    var aiRarity: String?

    init(from item: InventoryItem) {
        self.id = item.id
        self.definitionId = item.definitionId
        self.quantity = item.quantity
        self.qualityRaw = item.quality?.rawValue
        self.obtainedAt = item.obtainedAt
        self.obtainedFrom = item.obtainedFrom
        self.isAIGenerated = item.isAIGenerated
        self.aiName = item.aiName
        self.aiStory = item.aiStory
        self.aiCategory = item.aiCategory
        self.aiRarity = item.aiRarity
    }

    func toInventoryItem() -> InventoryItem {
        let quality: ItemQuality? = qualityRaw.flatMap { ItemQuality(rawValue: $0) }
        return InventoryItem(
            id: id,
            definitionId: definitionId,
            quantity: quantity,
            quality: quality,
            obtainedAt: obtainedAt,
            obtainedFrom: obtainedFrom,
            isAIGenerated: isAIGenerated,
            aiName: aiName,
            aiStory: aiStory,
            aiCategory: aiCategory,
            aiRarity: aiRarity
        )
    }
}

/// 探索统计的 Codable 包装
private struct ExplorationStatsCodable: Codable {
    var totalWalkDistance: Double
    var todayWalkDistance: Double
    var walkDistanceRank: Int
    var totalExplorationTime: TimeInterval
    var totalPOIsDiscovered: Int
    var totalItemsCollected: Int

    init(from stats: ExplorationStats) {
        self.totalWalkDistance = stats.totalWalkDistance
        self.todayWalkDistance = stats.todayWalkDistance
        self.walkDistanceRank = stats.walkDistanceRank
        self.totalExplorationTime = stats.totalExplorationTime
        self.totalPOIsDiscovered = stats.totalPOIsDiscovered
        self.totalItemsCollected = stats.totalItemsCollected
    }

    func toExplorationStats() -> ExplorationStats {
        return ExplorationStats(
            totalWalkDistance: totalWalkDistance,
            todayWalkDistance: todayWalkDistance,
            walkDistanceRank: walkDistanceRank,
            totalExplorationTime: totalExplorationTime,
            totalPOIsDiscovered: totalPOIsDiscovered,
            totalItemsCollected: totalItemsCollected
        )
    }
}

// MARK: - CLLocationManagerDelegate（地理围栏回调）

extension ExplorationManager: CLLocationManagerDelegate {

    /// 进入地理围栏区域
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("🎯 [地理围栏] didEnterRegion 被调用: \(region.identifier)")

        Task { @MainActor in
            handleGeofenceEntry(regionIdentifier: region.identifier)
        }
    }

    /// 处理地理围栏进入事件（主线程）
    private func handleGeofenceEntry(regionIdentifier: String) {
        // 查找对应的 POI
        guard let poi = nearbyPOIs.first(where: { $0.id.uuidString == regionIdentifier }) else {
            print("⚠️ [地理围栏] 未找到对应 POI: \(regionIdentifier)")
            return
        }

        // 检查是否已提示过
        guard !promptedPOIs.contains(poi.id) else {
            print("🎯 [地理围栏] POI 已提示过，跳过: \(poi.name)")
            return
        }

        // 检查是否可搜刮
        guard poi.status != .looted else {
            print("🎯 [地理围栏] POI 已被搜刮，跳过: \(poi.name)")
            return
        }

        print("🎯 [地理围栏] 进入 POI 范围: \(poi.name)")

        // 设置当前可搜刮的 POI
        currentLootablePOI = poi
        showLootPrompt = true
        promptedPOIs.insert(poi.id)

        // 触发震动反馈
        triggerProximityFeedback()
    }

    /// 开始监控地理围栏
    nonisolated func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("🎯 [地理围栏] 开始监控: \(region.identifier)")

        // 立即检查当前是否已在围栏内
        manager.requestState(for: region)
    }

    /// 地理围栏状态确定
    nonisolated func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        let stateString: String
        switch state {
        case .inside:
            stateString = "内部"
            // 如果已经在围栏内，触发进入事件
            Task { @MainActor in
                handleGeofenceEntry(regionIdentifier: region.identifier)
            }
        case .outside:
            stateString = "外部"
        case .unknown:
            stateString = "未知"
        @unknown default:
            stateString = "未知"
        }
        print("🎯 [地理围栏] 状态确定: \(region.identifier) -> \(stateString)")
    }

    /// 地理围栏监控失败
    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("❌ [地理围栏] 监控失败: \(region?.identifier ?? "unknown") - \(error.localizedDescription)")
    }
}

// MARK: - 探索错误

enum ExplorationError: LocalizedError {
    case locationUnavailable
    case poiNotFound
    case tooFarAway(distance: Double)
    case alreadyLooted
    case backpackFull
    case itemNotFound
    case itemDefinitionNotFound
    case insufficientQuantity

    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            return "无法获取当前位置"
        case .poiNotFound:
            return "找不到该 POI"
        case .tooFarAway(let distance):
            return "距离太远（\(String(format: "%.0f", distance))米），需要在 100 米内才能搜刮"
        case .alreadyLooted:
            return "该 POI 已被搜寻过"
        case .backpackFull:
            return "背包已满，请先清理物品"
        case .itemNotFound:
            return "找不到该物品"
        case .itemDefinitionNotFound:
            return "物品定义缺失"
        case .insufficientQuantity:
            return "数量不足"
        }
    }
}
