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
//

import Foundation
import CoreLocation
import Combine

/// 探索管理器
@MainActor
class ExplorationManager: ObservableObject {

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

    // MARK: - 私有属性

    private var cancellables = Set<AnyCancellable>()
    private let locationManager = LocationManager()

    /// POI 发现距离阈值（米）
    private let discoveryRadius: Double = 50.0

    /// POI 搜寻距离阈值（米）
    private let searchRadius: Double = 10.0

    /// 背包最大容量
    private let maxBackpackCapacity = 100

    // MARK: - 初始化

    private init() {
        setupLocationObserver()
        loadMockData()
    }

    // MARK: - 位置监听

    /// 设置位置监听
    private func setupLocationObserver() {
        locationManager.$userLocation
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                self?.currentLocation = coordinate
                Task {
                    await self?.checkNearbyPOIs()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - POI 发现

    /// 检查附近的 POI
    func checkNearbyPOIs() async {
        guard let currentLocation = currentLocation else { return }

        // TODO: 从 Supabase 加载真实 POI 数据
        // 目前使用 mock 数据
        let allPOIs = MockExplorationData.mockPOIs

        // 计算距离并筛选附近的 POI
        nearbyPOIs = allPOIs.map { poi in
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
        guard let currentLocation = currentLocation else {
            throw ExplorationError.locationUnavailable
        }

        guard let poiIndex = nearbyPOIs.firstIndex(where: { $0.id == poiId }) else {
            throw ExplorationError.poiNotFound
        }

        let poi = nearbyPOIs[poiIndex]

        // 检查距离
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

        // 生成掉落物品
        let collectedItems = generateLoot(for: poi)

        // 添加到背包
        for item in collectedItems {
            addItemToInventory(item: item)
        }

        // 更新 POI 状态
        nearbyPOIs[poiIndex].status = .looted
        nearbyPOIs[poiIndex].availableLoot = []

        // 更新统计
        // explorationStats.totalPOIsLooted += 1
        explorationStats.totalItemsCollected += collectedItems.count

        // TODO: 添加稀有度统计到 ExplorationStats
        // 更新稀有度统计
        // for item in collectedItems {
        //     if let definition = MockExplorationData.getItemDefinition(by: item.definitionId) {
        //         switch definition.rarity {
        //         case .common:
        //             explorationStats.commonItemsFound += 1
        //         case .uncommon:
        //             explorationStats.uncommonItemsFound += 1
        //         case .rare:
        //             explorationStats.rareItemsFound += 1
        //         case .epic:
        //             explorationStats.epicItemsFound += 1
        //         case .legendary:
        //             explorationStats.legendaryItemsFound += 1
        //         }
        //     }
        // }

        // TODO: 同步到 Supabase

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

    /// 生成 POI 掉落物品
    private func generateLoot(for poi: POI) -> [InventoryItem] {
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
                obtainedFrom: poi.name
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

        // TODO: 同步到 Supabase
    }

    // MARK: - 数据加载

    /// 加载玩家数据（从 Supabase）
    func loadPlayerData() async {
        isLoading = true
        errorMessage = nil

        do {
            // TODO: 实现 Supabase 数据加载
            // 1. 加载背包物品
            // 2. 加载探索统计
            // 3. 加载已发现的 POI

            // 暂时使用 mock 数据
            loadMockData()

            isLoading = false
        } catch {
            errorMessage = "加载数据失败: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// 加载 Mock 数据（用于测试）
    private func loadMockData() {
        inventoryItems = MockExplorationData.mockInventoryItems
        nearbyPOIs = MockExplorationData.mockPOIs

        Task {
            await checkNearbyPOIs()
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

        loadMockData()
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
            return "距离太远（\(String(format: "%.0f", distance))米），需要在 10 米内才能搜寻"
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
