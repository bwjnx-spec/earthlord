//
//  BuildingManager.swift
//  earthlord
//
//  Created on 2025/01/28.
//

import Foundation
import Combine
import CoreLocation
import Supabase

/// 建筑管理器
/// 负责建筑模板加载、建造、升级和 Supabase 同步
@MainActor
class BuildingManager: ObservableObject {

    // MARK: - Singleton

    static let shared = BuildingManager()

    // MARK: - Published Properties

    /// 建筑模板列表
    @Published var templates: [BuildingTemplate] = []

    /// 当前领地的建筑列表
    @Published var playerBuildings: [PlayerBuilding] = []

    /// 加载状态
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String? = nil

    // MARK: - Private Properties

    private let supabase: SupabaseClient
    private var constructionTimer: Timer?

    // MARK: - Initialization

    nonisolated init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    private convenience init() {
        self.init(supabase: supabaseClient)
    }

    // MARK: - 模板加载

    /// 从 Bundle 加载建筑模板 JSON
    func loadTemplates() {
        guard let url = Bundle.main.url(forResource: "building_templates", withExtension: "json") else {
            print("❌ 未找到 building_templates.json")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            templates = try decoder.decode([BuildingTemplate].self, from: data)
            print("✅ 加载了 \(templates.count) 个建筑模板")
        } catch {
            print("❌ 建筑模板解析失败: \(error)")
        }
    }

    /// 根据 templateId 查找模板
    func getTemplate(by templateId: String) -> BuildingTemplate? {
        return templates.first { $0.templateId == templateId }
    }

    // MARK: - 建造检查

    /// 检查是否可以建造指定建筑
    /// - Parameters:
    ///   - template: 建筑模板
    ///   - territoryId: 领地 ID
    ///   - playerResources: 玩家资源（definitionId -> 数量）
    /// - Returns: (是否可以建造, 错误信息)
    func canBuild(
        template: BuildingTemplate,
        territoryId: UUID,
        playerResources: [String: Int]
    ) -> (Bool, BuildingError?) {
        // 1. 检查资源是否充足
        var missingResources: [String: Int] = [:]
        for (resourceId, requiredAmount) in template.requiredResources {
            let owned = playerResources[resourceId] ?? 0
            if owned < requiredAmount {
                missingResources[resourceId] = requiredAmount - owned
            }
        }

        if !missingResources.isEmpty {
            return (false, .insufficientResources(missing: missingResources))
        }

        // 2. 检查领地内该类型建筑数量上限
        let existingCount = playerBuildings.filter {
            $0.territoryId == territoryId && $0.templateId == template.templateId
        }.count

        if existingCount >= template.maxPerTerritory {
            return (false, .maxBuildingsReached(templateId: template.templateId, max: template.maxPerTerritory))
        }

        return (true, nil)
    }

    /// 从背包获取当前资源统计
    func getCurrentResources() -> [String: Int] {
        var resources: [String: Int] = [:]
        for item in ExplorationManager.shared.inventoryItems {
            resources[item.definitionId, default: 0] += item.quantity
        }
        return resources
    }

    // MARK: - 建造操作

    /// 开始建造建筑
    /// - Parameters:
    ///   - templateId: 建筑模板 ID
    ///   - territoryId: 领地 ID
    ///   - location: 建筑位置坐标
    /// - Throws: BuildingError
    func startConstruction(
        templateId: String,
        territoryId: UUID,
        location: CLLocationCoordinate2D
    ) async throws {
        // 1. 查找模板
        guard let template = getTemplate(by: templateId) else {
            throw BuildingError.templateNotFound(templateId: templateId)
        }

        // 2. 获取用户 ID
        let userId: UUID
        do {
            let session = try await supabase.auth.session
            userId = session.user.id
        } catch {
            throw BuildingError.notAuthenticated
        }

        // 3. 检查是否可以建造
        let resources = getCurrentResources()
        let (canBuild, buildError) = canBuild(template: template, territoryId: territoryId, playerResources: resources)
        if !canBuild {
            throw buildError!
        }

        // 4. 扣除资源（两阶段：先验证再扣除）
        deductResources(template.requiredResources)

        // 5. 插入数据库
        let now = Date()
        let completedAt = now.addingTimeInterval(TimeInterval(template.buildTimeSeconds))

        let buildingData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "territory_id": .string(territoryId.uuidString),
            "template_id": .string(template.templateId),
            "building_name": .string(template.name),
            "status": .string(BuildingStatus.constructing.rawValue),
            "level": .integer(1),
            "location_lat": .double(location.latitude),
            "location_lon": .double(location.longitude),
            "build_started_at": .string(ISO8601DateFormatter().string(from: now)),
            "build_completed_at": .string(ISO8601DateFormatter().string(from: completedAt))
        ]

        do {
            let response: PlayerBuilding = try await supabase
                .from("player_buildings")
                .insert(buildingData)
                .select()
                .single()
                .execute()
                .value

            playerBuildings.append(response)
            print("✅ 开始建造: \(template.name)，预计 \(template.buildTimeSeconds) 秒完成")

            // 6. 启动建造计时器
            startConstructionTimer()

        } catch {
            // 回滚资源
            rollbackResources(template.requiredResources)
            print("❌ 建造失败，已回滚资源: \(error)")
            throw BuildingError.networkError(underlying: error)
        }
    }

    /// 完成建造
    /// - Parameter buildingId: 建筑 ID
    func completeConstruction(buildingId: UUID) async throws {
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound(buildingId: buildingId)
        }

        guard playerBuildings[index].status == .constructing else {
            throw BuildingError.invalidStatus(current: playerBuildings[index].status, expected: .constructing)
        }

        do {
            try await supabase
                .from("player_buildings")
                .update(["status": AnyJSON.string(BuildingStatus.active.rawValue)])
                .eq("id", value: buildingId.uuidString)
                .execute()

            playerBuildings[index].status = .active
            print("✅ 建造完成: \(playerBuildings[index].buildingName)")

        } catch {
            throw BuildingError.networkError(underlying: error)
        }
    }

    // MARK: - 升级

    /// 升级建筑
    /// - Parameter buildingId: 建筑 ID
    func upgradeBuilding(buildingId: UUID) async throws {
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound(buildingId: buildingId)
        }

        let building = playerBuildings[index]

        // 检查状态
        guard building.status == .active else {
            throw BuildingError.invalidStatus(current: building.status, expected: .active)
        }

        // 检查等级上限
        guard let template = getTemplate(by: building.templateId) else {
            throw BuildingError.templateNotFound(templateId: building.templateId)
        }

        guard building.level < template.maxLevel else {
            throw BuildingError.maxBuildingsReached(templateId: template.templateId, max: template.maxLevel)
        }

        let newLevel = building.level + 1

        do {
            try await supabase
                .from("player_buildings")
                .update(["level": AnyJSON.integer(newLevel)])
                .eq("id", value: buildingId.uuidString)
                .execute()

            playerBuildings[index].level = newLevel
            print("✅ 建筑升级: \(building.buildingName) → Lv.\(newLevel)")

        } catch {
            throw BuildingError.networkError(underlying: error)
        }
    }

    // MARK: - 拆除

    /// 拆除建筑
    /// - Parameter buildingId: 建筑 ID
    func demolishBuilding(buildingId: UUID) async throws {
        guard playerBuildings.contains(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound(buildingId: buildingId)
        }

        do {
            try await supabase
                .from("player_buildings")
                .delete()
                .eq("id", value: buildingId.uuidString)
                .execute()

            playerBuildings.removeAll { $0.id == buildingId }
            print("✅ 建筑已拆除: \(buildingId)")
        } catch {
            throw BuildingError.networkError(underlying: error)
        }
    }

    // MARK: - 数据查询

    /// 从 Supabase 加载当前用户在指定领地的建筑
    /// - Parameter territoryId: 领地 ID（可选，不传则加载所有）
    func fetchPlayerBuildings(territoryId: UUID? = nil) async throws {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.session
            let userId = session.user.id

            var query = supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId.uuidString)

            if let territoryId = territoryId {
                query = query.eq("territory_id", value: territoryId.uuidString)
            }

            let response: [PlayerBuilding] = try await query
                .execute()
                .value

            playerBuildings = response
            print("✅ 加载了 \(response.count) 个建筑")

            // 启动计时器检查建造中的建筑
            if playerBuildings.contains(where: { $0.status == .constructing }) {
                startConstructionTimer()
            }

        } catch {
            errorMessage = "加载建筑失败: \(error.localizedDescription)"
            print("❌ 加载建筑失败: \(error)")
            throw BuildingError.networkError(underlying: error)
        }

        isLoading = false
    }

    // MARK: - 资源操作（Private）

    /// 扣除背包资源
    private func deductResources(_ required: [String: Int]) {
        for (resourceId, amount) in required {
            var remaining = amount
            // 遍历背包找到对应物品并扣减
            for i in (0..<ExplorationManager.shared.inventoryItems.count).reversed() {
                guard ExplorationManager.shared.inventoryItems[i].definitionId == resourceId else { continue }
                guard remaining > 0 else { break }

                let available = ExplorationManager.shared.inventoryItems[i].quantity
                if available <= remaining {
                    remaining -= available
                    ExplorationManager.shared.inventoryItems.remove(at: i)
                } else {
                    ExplorationManager.shared.inventoryItems[i].quantity -= remaining
                    remaining = 0
                }
            }
        }
        ExplorationManager.shared.saveInventoryData()
    }

    /// 回滚资源（建造失败时退还）
    private func rollbackResources(_ required: [String: Int]) {
        for (resourceId, amount) in required {
            let item = InventoryItem(
                id: UUID(),
                definitionId: resourceId,
                quantity: amount,
                quality: nil,
                obtainedAt: Date(),
                obtainedFrom: "建造退还"
            )
            ExplorationManager.shared.addItemToInventory(item: item)
        }
    }

    // MARK: - 建造计时器

    /// 启动建造计时器，每秒检查是否有建筑建造完成
    private func startConstructionTimer() {
        // 避免重复启动
        guard constructionTimer == nil else { return }

        constructionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkConstructionCompletion()
            }
        }
    }

    /// 停止建造计时器
    private func stopConstructionTimer() {
        constructionTimer?.invalidate()
        constructionTimer = nil
    }

    /// 检查并完成已到期的建造
    private func checkConstructionCompletion() async {
        objectWillChange.send()
        let constructingBuildings = playerBuildings.filter { $0.status == .constructing }

        if constructingBuildings.isEmpty {
            stopConstructionTimer()
            return
        }

        for building in constructingBuildings {
            if building.remainingBuildTime <= 0 {
                do {
                    try await completeConstruction(buildingId: building.id)
                } catch {
                    print("❌ 自动完成建造失败: \(error)")
                }
            }
        }
    }
}
