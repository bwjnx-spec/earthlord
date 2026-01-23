//
//  MockExplorationData.swift
//  earthlord
//
//  探索模块测试假数据
//  用于开发和测试探索功能，包括 POI、背包、物品定义和探索结果
//

import Foundation
import CoreLocation

// MARK: - 物品稀有度

/// 物品稀有度枚举
/// 用于标识物品的稀缺程度，影响发现概率和交易价值
enum ItemRarity: String, CaseIterable {
    case common = "普通"      // 白色 - 随处可见
    case uncommon = "良好"    // 绿色 - 较为常见
    case rare = "稀有"        // 蓝色 - 不太常见
    case epic = "史诗"        // 紫色 - 非常稀有
    case legendary = "传说"   // 橙色 - 极其稀有
}

// MARK: - 物品品质

/// 物品品质枚举
/// 用于标识物品的损耗程度，影响使用效果
enum ItemQuality: String, CaseIterable {
    case pristine = "完好"    // 100% 效果
    case good = "良好"        // 80% 效果
    case worn = "磨损"        // 60% 效果
    case damaged = "破损"     // 40% 效果
    case broken = "损坏"      // 20% 效果，需要修复
}

// MARK: - 物品分类

/// 物品分类枚举
/// 用于背包分类显示和筛选
enum ItemCategory: String, CaseIterable {
    case water = "水源"       // 饮用水类
    case food = "食物"        // 食品类
    case medical = "医疗"     // 医疗用品
    case material = "材料"    // 制作材料
    case tool = "工具"        // 工具装备
    case weapon = "武器"      // 武器类
    case clothing = "服装"    // 服装护甲
    case misc = "杂物"        // 其他杂物
}

// MARK: - POI 状态

/// POI 发现状态枚举
/// 用于标识兴趣点的当前状态
enum POIStatus: String {
    case undiscovered = "未发现"      // 玩家未到达，地图上不显示或显示为问号
    case discovered = "已发现"        // 玩家已到达，但未搜索
    case hasLoot = "有物资"           // 已搜索，还有物资可拾取
    case looted = "已搜空"            // 已被完全搜索，没有物资了
    case dangerous = "危险"           // 有危险，需要特殊条件才能进入
}

// MARK: - POI 类型

/// POI 类型枚举
/// 用于标识兴趣点的建筑类型，影响可发现物品的种类
enum POIType: String {
    case supermarket = "超市"         // 食物、水、日用品
    case hospital = "医院"            // 医疗用品
    case gasStation = "加油站"        // 燃料、工具
    case pharmacy = "药店"            // 药品
    case factory = "工厂"             // 材料、工具
    case warehouse = "仓库"           // 各种物资
    case residence = "民居"           // 日用品、食物
    case policeStation = "警局"       // 武器、装备
    case fireStation = "消防站"       // 工具、装备
}

// MARK: - 物品定义

/// 物品定义结构体
/// 记录每种物品的基础属性，用于物品生成和显示
struct ItemDefinition: Identifiable {
    let id: String                    // 物品唯一标识（英文）
    let name: String                  // 物品中文名
    let category: ItemCategory        // 物品分类
    let weight: Double                // 单个重量（千克）
    let volume: Double                // 单个体积（升）
    let rarity: ItemRarity            // 稀有度
    let stackable: Bool               // 是否可堆叠
    let maxStack: Int                 // 最大堆叠数量
    let hasQuality: Bool              // 是否有品质属性
    let description: String           // 物品描述
}

// MARK: - 背包物品

/// 背包物品结构体
/// 代表玩家背包中的一个物品槽位
struct InventoryItem: Identifiable {
    let id: UUID                      // 物品实例唯一 ID
    let definitionId: String          // 对应的物品定义 ID
    var quantity: Int                 // 数量
    var quality: ItemQuality?         // 品质（可选，部分物品没有品质）
    let obtainedAt: Date              // 获得时间
    let obtainedFrom: String?         // 获得来源（POI 名称等）
}

// MARK: - POI 结构体

/// 兴趣点结构体
/// 代表地图上的一个可探索地点
struct POI: Identifiable, Hashable {
    let id: UUID                      // POI 唯一 ID
    let name: String                  // POI 名称
    let type: POIType                 // POI 类型
    let coordinate: CLLocationCoordinate2D  // 位置坐标 (WGS84)
    let location: CLLocationCoordinate2D  // 位置坐标别名（用于兼容）
    var status: POIStatus             // 当前状态
    let discoveredAt: Date?           // 发现时间（未发现时为 nil）
    let lootItems: [String]           // 可拾取物品的定义 ID 列表（用于显示）
    var availableLoot: [String]       // 当前可搜寻的物品 ID 列表
    let dangerLevel: Int              // 危险等级 1-5
    let description: String           // POI 描述
    var distance: Double?             // 距离玩家的距离（米）- 动态计算

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: POI, rhs: POI) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 探索结果

/// 探索结果结构体
/// 记录一次 POI 搜寻的成果
struct ExplorationResult: Identifiable {
    let id: String                    // 结果唯一 ID
    let poiId: String                 // POI ID
    let poiName: String               // POI 名称
    let timestamp: Date               // 搜寻时间
    let itemsCollected: [InventoryItem]  // 收集的物品列表
    let experienceGained: Int         // 获得的经验值
}

// MARK: - 探索会话结果

/// 探索会话结果结构体
/// 记录一次完整的探索会话的成果（区别于单个 POI 搜寻）
struct ExplorationSessionResult: Identifiable {
    let id: String                    // 会话唯一 ID
    let startTime: Date               // 开始时间
    let endTime: Date                 // 结束时间
    let walkDistance: Double          // 本次行走距离（米）
    let totalWalkDistance: Double     // 累计行走距离（米）
    let walkDistanceRank: Int         // 行走距离排名
    let exploredArea: Double          // 本次探索面积（平方米）
    let totalExploredArea: Double     // 累计探索面积（平方米）
    let exploredAreaRank: Int         // 探索面积排名
    let itemsCollected: [InventoryItem]  // 收集的物品列表
    let experienceGained: Int         // 获得的经验值

    /// 探索时长（秒）
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

// MARK: - 探索统计

/// 探索统计结构体
/// 记录玩家的累计探索数据和排名
struct ExplorationStats {
    // 行走距离统计
    var totalWalkDistance: Double     // 累计行走距离（米）
    var todayWalkDistance: Double     // 今日行走距离（米）
    var walkDistanceRank: Int         // 行走距离排名

    // 探索面积统计
    var totalExploredArea: Double     // 累计探索面积（平方米）
    var todayExploredArea: Double     // 今日探索面积（平方米）
    var exploredAreaRank: Int         // 探索面积排名

    // 其他统计
    var totalExplorationTime: TimeInterval  // 累计探索时长（秒）
    var totalPOIsDiscovered: Int      // 累计发现 POI 数量
    var totalItemsCollected: Int      // 累计收集物品数量
}

// MARK: - Mock 数据类

/// 探索模块测试假数据
/// 提供静态的测试数据，用于开发和调试探索功能
struct MockExplorationData {

    // MARK: - 物品定义表

    /// 所有物品的定义
    /// 用于创建物品实例时查询基础属性
    static let itemDefinitions: [ItemDefinition] = [
        // ===== 水源类 =====
        ItemDefinition(
            id: "water_bottle",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            stackable: true,
            maxStack: 10,
            hasQuality: false,
            description: "一瓶干净的饮用水，可以恢复口渴值"
        ),
        ItemDefinition(
            id: "water_purified",
            name: "净化水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .uncommon,
            stackable: true,
            maxStack: 10,
            hasQuality: false,
            description: "经过净化处理的饮用水，更加安全"
        ),

        // ===== 食物类 =====
        ItemDefinition(
            id: "canned_food",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            stackable: true,
            maxStack: 10,
            hasQuality: true,
            description: "密封的罐头食品，保质期较长"
        ),
        ItemDefinition(
            id: "biscuit",
            name: "压缩饼干",
            category: .food,
            weight: 0.2,
            volume: 0.1,
            rarity: .common,
            stackable: true,
            maxStack: 20,
            hasQuality: true,
            description: "高能量压缩饼干，便于携带"
        ),
        ItemDefinition(
            id: "energy_bar",
            name: "能量棒",
            category: .food,
            weight: 0.1,
            volume: 0.05,
            rarity: .uncommon,
            stackable: true,
            maxStack: 20,
            hasQuality: false,
            description: "高热量能量棒，快速补充体力"
        ),

        // ===== 医疗类 =====
        ItemDefinition(
            id: "bandage",
            name: "绷带",
            category: .medical,
            weight: 0.1,
            volume: 0.05,
            rarity: .common,
            stackable: true,
            maxStack: 20,
            hasQuality: true,
            description: "医用绷带，用于包扎伤口"
        ),
        ItemDefinition(
            id: "medicine",
            name: "药品",
            category: .medical,
            weight: 0.05,
            volume: 0.02,
            rarity: .uncommon,
            stackable: true,
            maxStack: 10,
            hasQuality: false,
            description: "常用药品，可以治疗轻微疾病"
        ),
        ItemDefinition(
            id: "first_aid_kit",
            name: "急救包",
            category: .medical,
            weight: 0.8,
            volume: 0.5,
            rarity: .rare,
            stackable: false,
            maxStack: 1,
            hasQuality: true,
            description: "完整的急救包，包含多种医疗用品"
        ),
        ItemDefinition(
            id: "painkiller",
            name: "止痛药",
            category: .medical,
            weight: 0.05,
            volume: 0.02,
            rarity: .uncommon,
            stackable: true,
            maxStack: 10,
            hasQuality: false,
            description: "止痛药片，可以暂时缓解疼痛"
        ),

        // ===== 材料类 =====
        ItemDefinition(
            id: "wood",
            name: "木材",
            category: .material,
            weight: 1.0,
            volume: 2.0,
            rarity: .common,
            stackable: true,
            maxStack: 50,
            hasQuality: false,
            description: "普通木材，用于建造和制作"
        ),
        ItemDefinition(
            id: "scrap_metal",
            name: "废金属",
            category: .material,
            weight: 0.8,
            volume: 0.3,
            rarity: .common,
            stackable: true,
            maxStack: 50,
            hasQuality: false,
            description: "废弃的金属碎片，可以熔炼再利用"
        ),
        ItemDefinition(
            id: "cloth",
            name: "布料",
            category: .material,
            weight: 0.2,
            volume: 0.3,
            rarity: .common,
            stackable: true,
            maxStack: 30,
            hasQuality: false,
            description: "普通布料，用于制作衣物和绷带"
        ),
        ItemDefinition(
            id: "electronics",
            name: "电子元件",
            category: .material,
            weight: 0.3,
            volume: 0.1,
            rarity: .rare,
            stackable: true,
            maxStack: 20,
            hasQuality: false,
            description: "可用的电子元件，用于制作高级物品"
        ),

        // ===== 工具类 =====
        ItemDefinition(
            id: "flashlight",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.2,
            rarity: .uncommon,
            stackable: false,
            maxStack: 1,
            hasQuality: true,
            description: "便携式手电筒，需要电池"
        ),
        ItemDefinition(
            id: "rope",
            name: "绳子",
            category: .tool,
            weight: 0.5,
            volume: 0.3,
            rarity: .common,
            stackable: true,
            maxStack: 5,
            hasQuality: true,
            description: "结实的绳子，用于攀爬和捆绑"
        ),
        ItemDefinition(
            id: "knife",
            name: "小刀",
            category: .tool,
            weight: 0.2,
            volume: 0.05,
            rarity: .uncommon,
            stackable: false,
            maxStack: 1,
            hasQuality: true,
            description: "多功能小刀，用于切割和防身"
        ),
        ItemDefinition(
            id: "lockpick",
            name: "开锁工具",
            category: .tool,
            weight: 0.1,
            volume: 0.02,
            rarity: .rare,
            stackable: true,
            maxStack: 5,
            hasQuality: true,
            description: "精密的开锁工具，可以打开锁住的门和箱子"
        ),
    ]

    // MARK: - POI 列表

    /// 测试用 POI 列表
    /// 包含 5 个不同状态的兴趣点，用于测试地图显示和交互
    static let mockPOIs: [POI] = [
        // 废弃超市 - 已发现，有物资
        POI(
            id: UUID(),
            name: "废弃超市",
            type: .supermarket,
            coordinate: CLLocationCoordinate2D(latitude: 30.409200, longitude: 104.171100),
            location: CLLocationCoordinate2D(latitude: 30.409200, longitude: 104.171100),
            status: .hasLoot,
            discoveredAt: Date().addingTimeInterval(-86400), // 1天前发现
            lootItems: ["water_bottle", "canned_food", "biscuit"],
            availableLoot: ["water_bottle", "canned_food", "biscuit"],
            dangerLevel: 2,
            description: "一家废弃的小型超市，货架上还残留着一些物资",
            distance: nil
        ),

        // 医院废墟 - 已发现，已被搜空
        POI(
            id: UUID(),
            name: "医院废墟",
            type: .hospital,
            coordinate: CLLocationCoordinate2D(latitude: 30.410500, longitude: 104.172300),
            location: CLLocationCoordinate2D(latitude: 30.410500, longitude: 104.172300),
            status: .looted,
            discoveredAt: Date().addingTimeInterval(-172800), // 2天前发现
            lootItems: [],
            availableLoot: [],
            dangerLevel: 4,
            description: "曾经的医院，现在只剩下断壁残垣，物资已被搜刮一空",
            distance: nil
        ),

        // 加油站 - 未发现
        POI(
            id: UUID(),
            name: "加油站",
            type: .gasStation,
            coordinate: CLLocationCoordinate2D(latitude: 30.408000, longitude: 104.170000),
            location: CLLocationCoordinate2D(latitude: 30.408000, longitude: 104.170000),
            status: .undiscovered,
            discoveredAt: nil,
            lootItems: ["scrap_metal", "rope", "cloth"],
            availableLoot: ["scrap_metal", "rope", "cloth"],
            dangerLevel: 3,
            description: "路边的加油站，可能还有可用的物资",
            distance: nil
        ),

        // 药店废墟 - 已发现，有物资
        POI(
            id: UUID(),
            name: "药店废墟",
            type: .pharmacy,
            coordinate: CLLocationCoordinate2D(latitude: 30.409800, longitude: 104.169500),
            location: CLLocationCoordinate2D(latitude: 30.409800, longitude: 104.169500),
            status: .hasLoot,
            discoveredAt: Date().addingTimeInterval(-43200), // 12小时前发现
            lootItems: ["bandage", "medicine", "painkiller"],
            availableLoot: ["bandage", "medicine", "painkiller"],
            dangerLevel: 2,
            description: "一家小药店的废墟，柜台后面可能还有药品",
            distance: nil
        ),

        // 工厂废墟 - 未发现
        POI(
            id: UUID(),
            name: "工厂废墟",
            type: .factory,
            coordinate: CLLocationCoordinate2D(latitude: 30.411000, longitude: 104.168000),
            location: CLLocationCoordinate2D(latitude: 30.411000, longitude: 104.168000),
            status: .undiscovered,
            discoveredAt: nil,
            lootItems: ["scrap_metal", "electronics", "wood", "rope"],
            availableLoot: ["scrap_metal", "electronics", "wood", "rope"],
            dangerLevel: 5,
            description: "废弃的工厂，里面可能有大量材料，但也非常危险",
            distance: nil
        ),
    ]

    // MARK: - 背包物品

    /// 测试用背包物品列表
    /// 包含 8 种不同类型的物品，用于测试背包显示和物品管理
    static let mockInventoryItems: [InventoryItem] = [
        // 矿泉水 - 水类，无品质
        InventoryItem(
            id: UUID(),
            definitionId: "water_bottle",
            quantity: 5,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-3600),
            obtainedFrom: "废弃超市"
        ),

        // 罐头食品 - 食物类，有品质
        InventoryItem(
            id: UUID(),
            definitionId: "canned_food",
            quantity: 3,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-7200),
            obtainedFrom: "废弃超市"
        ),

        // 绷带 - 医疗类，有品质
        InventoryItem(
            id: UUID(),
            definitionId: "bandage",
            quantity: 10,
            quality: .pristine,
            obtainedAt: Date().addingTimeInterval(-1800),
            obtainedFrom: "药店废墟"
        ),

        // 药品 - 医疗类，无品质
        InventoryItem(
            id: UUID(),
            definitionId: "medicine",
            quantity: 4,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-1800),
            obtainedFrom: "药店废墟"
        ),

        // 木材 - 材料类，无品质
        InventoryItem(
            id: UUID(),
            definitionId: "wood",
            quantity: 15,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-14400),
            obtainedFrom: "路边收集"
        ),

        // 废金属 - 材料类，无品质
        InventoryItem(
            id: UUID(),
            definitionId: "scrap_metal",
            quantity: 8,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-10800),
            obtainedFrom: "路边收集"
        ),

        // 手电筒 - 工具类，有品质
        InventoryItem(
            id: UUID(),
            definitionId: "flashlight",
            quantity: 1,
            quality: .worn,
            obtainedAt: Date().addingTimeInterval(-86400),
            obtainedFrom: "废弃超市"
        ),

        // 绳子 - 工具类，有品质
        InventoryItem(
            id: UUID(),
            definitionId: "rope",
            quantity: 2,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-43200),
            obtainedFrom: "路边收集"
        ),
    ]

    // MARK: - 探索结果示例

    /// 测试用探索结果
    /// 模拟一次 POI 搜寻结果
    static let mockExplorationResult = ExplorationResult(
        id: UUID().uuidString,
        poiId: mockPOIs[0].id.uuidString,
        poiName: mockPOIs[0].name,
        timestamp: Date(),
        itemsCollected: [
            InventoryItem(
                id: UUID(),
                definitionId: "wood",
                quantity: 5,
                quality: nil,
                obtainedAt: Date(),
                obtainedFrom: mockPOIs[0].name
            ),
            InventoryItem(
                id: UUID(),
                definitionId: "water_bottle",
                quantity: 3,
                quality: .good,
                obtainedAt: Date(),
                obtainedFrom: mockPOIs[0].name
            ),
        ],
        experienceGained: 75
    )

    // MARK: - 探索会话结果示例

    /// 测试用探索会话结果
    /// 模拟一次完整的探索会话成果
    static let mockExplorationSessionResult = ExplorationSessionResult(
        id: UUID().uuidString,
        startTime: Date().addingTimeInterval(-1800), // 30 分钟前开始
        endTime: Date(),                              // 刚刚结束
        walkDistance: 2500,                          // 本次行走 2.5 公里
        totalWalkDistance: 15000,                    // 累计 15 公里
        walkDistanceRank: 42,                        // 行走排名第 42
        exploredArea: 50000,                         // 本次探索 5 万平方米
        totalExploredArea: 320000,                   // 累计 32 万平方米
        exploredAreaRank: 68,                        // 面积排名第 68
        itemsCollected: [
            InventoryItem(
                id: UUID(),
                definitionId: "wood",
                quantity: 5,
                quality: nil,
                obtainedAt: Date(),
                obtainedFrom: "探索采集"
            ),
            InventoryItem(
                id: UUID(),
                definitionId: "water_bottle",
                quantity: 3,
                quality: .good,
                obtainedAt: Date(),
                obtainedFrom: "探索采集"
            ),
            InventoryItem(
                id: UUID(),
                definitionId: "canned_food",
                quantity: 2,
                quality: .worn,
                obtainedAt: Date(),
                obtainedFrom: "探索采集"
            ),
            InventoryItem(
                id: UUID(),
                definitionId: "bandage",
                quantity: 4,
                quality: .pristine,
                obtainedAt: Date(),
                obtainedFrom: "探索采集"
            ),
        ],
        experienceGained: 150
    )

    // MARK: - 探索统计

    /// 测试用探索统计数据
    /// 模拟玩家的累计探索成就和排名
    static let mockExplorationStats = ExplorationStats(
        // 行走距离
        totalWalkDistance: 15000,      // 累计 15 公里
        todayWalkDistance: 2500,       // 今日 2.5 公里
        walkDistanceRank: 42,          // 排名第 42

        // 探索面积
        totalExploredArea: 250000,     // 累计 25 万平方米
        todayExploredArea: 50000,      // 今日 5 万平方米
        exploredAreaRank: 38,          // 排名第 38

        // 其他统计
        totalExplorationTime: 36000,   // 累计探索 10 小时
        totalPOIsDiscovered: 23,       // 累计发现 23 个 POI
        totalItemsCollected: 156       // 累计收集 156 个物品
    )

    // MARK: - 辅助方法

    /// 根据 ID 获取物品定义
    /// - Parameter id: 物品定义 ID
    /// - Returns: 物品定义，未找到返回 nil
    static func getItemDefinition(by id: String) -> ItemDefinition? {
        return itemDefinitions.first { $0.id == id }
    }

    /// 计算背包总重量
    /// - Parameter items: 背包物品列表
    /// - Returns: 总重量（千克）
    static func calculateTotalWeight(items: [InventoryItem]) -> Double {
        return items.reduce(0) { total, item in
            guard let definition = getItemDefinition(by: item.definitionId) else { return total }
            return total + definition.weight * Double(item.quantity)
        }
    }

    /// 计算背包总体积
    /// - Parameter items: 背包物品列表
    /// - Returns: 总体积（升）
    static func calculateTotalVolume(items: [InventoryItem]) -> Double {
        return items.reduce(0) { total, item in
            guard let definition = getItemDefinition(by: item.definitionId) else { return total }
            return total + definition.volume * Double(item.quantity)
        }
    }

    /// 按分类筛选背包物品
    /// - Parameters:
    ///   - items: 背包物品列表
    ///   - category: 物品分类
    /// - Returns: 筛选后的物品列表
    static func filterItems(items: [InventoryItem], by category: ItemCategory) -> [InventoryItem] {
        return items.filter { item in
            guard let definition = getItemDefinition(by: item.definitionId) else { return false }
            return definition.category == category
        }
    }

    /// 格式化距离显示
    /// - Parameter meters: 距离（米）
    /// - Returns: 格式化的字符串（如 "2.5 公里" 或 "500 米"）
    static func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f 公里", meters / 1000)
        } else {
            return String(format: "%.0f 米", meters)
        }
    }

    /// 格式化面积显示
    /// - Parameter squareMeters: 面积（平方米）
    /// - Returns: 格式化的字符串（如 "5 万平方米" 或 "500 平方米"）
    static func formatArea(_ squareMeters: Double) -> String {
        if squareMeters >= 10000 {
            return String(format: "%.1f 万平方米", squareMeters / 10000)
        } else {
            return String(format: "%.0f 平方米", squareMeters)
        }
    }

    /// 格式化时间显示
    /// - Parameter seconds: 时间（秒）
    /// - Returns: 格式化的字符串（如 "30 分钟" 或 "2 小时 15 分钟"）
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            if minutes > 0 {
                return "\(hours) 小时 \(minutes) 分钟"
            } else {
                return "\(hours) 小时"
            }
        } else {
            return "\(minutes) 分钟"
        }
    }
}

// MARK: - 预览辅助

#if DEBUG
/// 用于 SwiftUI 预览的扩展
extension MockExplorationData {

    /// 打印所有测试数据摘要（调试用）
    static func printDataSummary() {
        print("===== 探索模块测试数据摘要 =====")
        print("物品定义: \(itemDefinitions.count) 种")
        print("POI 列表: \(mockPOIs.count) 个")
        print("背包物品: \(mockInventoryItems.count) 个")
        print("背包总重量: \(String(format: "%.1f", calculateTotalWeight(items: mockInventoryItems))) kg")
        print("背包总体积: \(String(format: "%.1f", calculateTotalVolume(items: mockInventoryItems))) L")
        print("累计行走: \(formatDistance(mockExplorationStats.totalWalkDistance))")
        print("累计探索: \(formatArea(mockExplorationStats.totalExploredArea))")
        print("================================")
    }
}
#endif
