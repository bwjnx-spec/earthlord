//
//  ProceduralPOIGenerator.swift
//  earthlord
//
//  Created for procedural POI generation
//

import Foundation
import CoreLocation

/// 程序化 POI 生成器
/// 基于 geohash 生成确定性的 POI，确保相同位置总是生成相同的 POI
class ProceduralPOIGenerator {
    static let shared = ProceduralPOIGenerator()

    // POI 类型权重分布（总和应为 100）
    private let typeWeights: [(type: POIType, weight: Int)] = [
        (.supermarket, 40),  // 超市最常见
        (.hospital, 20),     // 医疗设施
        (.gasStation, 15),   // 加油站
        (.pharmacy, 15),     // 药店
        (.warehouse, 10)     // 仓库
    ]

    // 末日风格前缀
    private let prefixes = [
        "废弃的", "荒废的", "破败的", "遗弃的", "被遗忘的",
        "坍塌的", "残破的", "幸存者的", "末日后的", "劫后余生的"
    ]

    // 区域名称组件
    private let areaTypes = [
        "东区", "西区", "南区", "北区", "中心区",
        "河畔", "山麓", "郊区", "工业区", "老城"
    ]

    private init() {}

    /// 生成指定位置周围的 POI
    /// - Parameters:
    ///   - center: 中心坐标
    ///   - radius: 搜索半径（米）
    ///   - maxCount: 最大生成数量（nil 表示使用默认值 5-8 个）
    /// - Returns: 生成的 POI 列表
    func generatePOIs(around center: CLLocationCoordinate2D, radius: Double = 1000.0, maxCount: Int? = nil) -> [POI] {
        // 计算当前位置的 geohash（精度 6，约 1.2km × 0.6km）
        let geohash = GeohashUtil.encode(
            latitude: center.latitude,
            longitude: center.longitude,
            precision: 6
        )

        print("🎲 [程序生成] Geohash: \(geohash)")
        print("🎲 [程序生成] 用户位置: (\(String(format: "%.6f", center.latitude)), \(String(format: "%.6f", center.longitude)))")

        // 使用 geohash 作为种子初始化随机数生成器
        var random = SeededRandom(seed: geohash)

        // 确定该单元应生成的 POI 数量
        // 如果指定了 maxCount，则使用该值；否则使用默认的 5-8 个
        let defaultCount = random.nextInt(in: 5...8)
        let poiCount = min(maxCount ?? defaultCount, defaultCount)
        print("🎲 [程序生成] 将生成 \(poiCount) 个 POI")

        var generatedPOIs: [POI] = []

        // 获取 geohash 单元边界
        let bounds = GeohashUtil.bounds(geohash: geohash)
        let cellWidth = bounds.maxLon - bounds.minLon
        let cellHeight = bounds.maxLat - bounds.minLat

        print("🎲 [程序生成] Geohash单元大小: 经度=\(String(format: "%.6f", cellWidth))° 纬度=\(String(format: "%.6f", cellHeight))°")

        for index in 0..<poiCount {
            // 为每个 POI 创建独立的随机数生成器（基于 geohash + index）
            var poiRandom = SeededRandom(seed: "\(geohash)_\(index)")

            // 根据权重选择 POI 类型
            let poiType = selectPOIType(using: &poiRandom)

            // 【修复】生成更近的 POI 分布（50-500米范围内）
            // 使用螺旋分布，但缩小偏移量
            let angle = Double(index) * 2.4 // 黄金角（约 137.5°）

            // 缩小距离因子，确保 POI 在 50-500 米范围内
            // 原来的 0.3 * sqrt(index+1) 会导致偏移量过大
            // 新的: 50-500米范围，分布在用户周围
            let minDistanceMeters: Double = 50.0
            let maxDistanceMeters: Double = 500.0
            let distanceMeters = minDistanceMeters + (maxDistanceMeters - minDistanceMeters) * Double(index) / Double(poiCount)

            // 转换为经纬度偏移（1度纬度≈111km，1度经度≈111km*cos(lat)）
            let metersPerDegreeLat = 111320.0
            let metersPerDegreeLon = 111320.0 * cos(center.latitude * .pi / 180.0)

            let offsetLat = sin(angle) * distanceMeters / metersPerDegreeLat
            let offsetLon = cos(angle) * distanceMeters / metersPerDegreeLon

            let coordinate = CLLocationCoordinate2D(
                latitude: center.latitude + offsetLat,
                longitude: center.longitude + offsetLon
            )

            print("🎲 [程序生成] POI #\(index): 距离=\(String(format: "%.0f", distanceMeters))m, 角度=\(String(format: "%.1f", angle * 180 / .pi))°")

            // 生成 POI 名称
            let name = generatePOIName(coordinate: coordinate, type: poiType, random: &poiRandom)

            // 生成物资列表
            let lootItems = generateLootItems(for: poiType, random: &poiRandom)

            // 生成描述
            let description = generateDescription(for: poiType, random: &poiRandom)

            // 创建 POI
            let poi = POI(
                id: UUID(),
                name: name,
                type: poiType,
                coordinate: coordinate,
                location: coordinate,  // 兼容字段
                status: .discovered,  // 程序生成的 POI 标记为已发现
                discoveredAt: Date(),
                lootItems: lootItems,
                availableLoot: lootItems,  // 初始时所有物品都可拾取
                dangerLevel: random.nextInt(in: 1...4),
                description: description,
                distance: nil,  // 距离需要外部计算
                source: .procedural,
                geohash: geohash,
                generatedAt: Date()
            )

            generatedPOIs.append(poi)

            print("  ✅ 生成: \(name) @ (\(coordinate.latitude), \(coordinate.longitude))")
        }

        return generatedPOIs
    }

    /// 根据权重选择 POI 类型
    private func selectPOIType(using random: inout SeededRandom) -> POIType {
        let totalWeight = typeWeights.reduce(0) { $0 + $1.weight }
        let randomValue = random.nextInt(in: 0..<totalWeight)

        var cumulativeWeight = 0
        for (type, weight) in typeWeights {
            cumulativeWeight += weight
            if randomValue < cumulativeWeight {
                return type
            }
        }

        return .supermarket // 默认回退
    }

    /// 生成 POI 描述
    private func generateDescription(for type: POIType, random: inout SeededRandom) -> String {
        let descriptions: [POIType: [String]] = [
            .hospital: [
                "废弃的医院大楼，走廊里一片寂静，医疗用品散落一地",
                "破败的医疗设施，空荡的病房里可能还有剩余的药品",
                "曾经救死扶伤的地方，如今只剩下空荡的走廊和残留的物资"
            ],
            .pharmacy: [
                "药店的玻璃柜台已经布满灰尘，但药柜里可能还有遗漏的药品",
                "破旧的药店，虽然被搜刮过多次，角落里也许还有惊喜",
                "招牌已经褪色的药店，货架后面可能藏着有用的医疗用品"
            ],
            .gasStation: [
                "废弃的加油站，便利店的货架空空如也，但储物间可能有工具",
                "锈迹斑斑的加油站，油罐早已干涸，但还可能找到其他物资",
                "荒废的加油站旁，散落着各种被遗弃的物品"
            ],
            .supermarket: [
                "超市的货架大多已空，但角落里可能还有被遗忘的罐头",
                "破败的超市，购物车东倒西歪，仓库深处也许还有物资",
                "废弃的商店，虽然被洗劫过，总还能找到一些有用的东西"
            ],
            .warehouse: [
                "巨大的仓库里堆满了灰尘覆盖的箱子，值得仔细搜寻",
                "废弃的仓储设施，昏暗的空间里藏着各种材料",
                "这里曾存放着大量货物，现在成了拾荒者的宝库"
            ],
            .factory: [
                "工厂的机器早已锈蚀停转，车间里散落着各种材料和工具",
                "破败的工业设施，虽然危险，但里面的物资值得冒险",
                "空荡的厂房里回荡着风声，也许还能找到有用的零件"
            ]
        ]

        if let typeDescriptions = descriptions[type],
           let description = random.choose(from: typeDescriptions) {
            return description
        }

        return "这个地方看起来还有物资可以搜寻"
    }

    /// 生成 POI 名称
    private func generatePOIName(
        coordinate: CLLocationCoordinate2D,
        type: POIType,
        random: inout SeededRandom
    ) -> String {
        // 选择前缀
        guard let prefix = random.choose(from: prefixes) else {
            return "未知地点"
        }

        // 选择区域名称
        guard let area = random.choose(from: areaTypes) else {
            return "\(prefix)\(type.rawValue)"
        }

        // 组合名称
        let typeName: String
        switch type {
        case .supermarket:
            typeName = random.nextDouble() < 0.5 ? "超市" : "商店"
        case .hospital:
            typeName = random.nextDouble() < 0.5 ? "医院" : "诊所"
        case .gasStation:
            typeName = "加油站"
        case .pharmacy:
            typeName = random.nextDouble() < 0.5 ? "药店" : "药房"
        case .warehouse:
            typeName = random.nextDouble() < 0.5 ? "仓库" : "储物间"
        case .factory:
            typeName = random.nextDouble() < 0.5 ? "工厂" : "车间"
        case .residence:
            typeName = random.nextDouble() < 0.5 ? "民居" : "住宅"
        case .policeStation:
            typeName = "警局"
        case .fireStation:
            typeName = "消防站"
        }

        // 20% 概率添加"废墟"后缀
        let suffix = random.nextDouble() < 0.2 ? "废墟" : ""

        return "\(prefix)\(area)\(typeName)\(suffix)"
    }

    /// 生成物资列表（返回物品定义 ID）
    private func generateLootItems(for type: POIType, random: inout SeededRandom) -> [String] {
        var items: [String] = []

        switch type {
        case .supermarket:
            // 超市：食物为主
            items.append("water_bottle")
            items.append("canned_food")
            if random.nextDouble() < 0.7 {
                items.append("biscuit")
            }
            if random.nextDouble() < 0.5 {
                items.append("energy_bar")
            }

        case .hospital:
            // 医院：医疗用品为主
            items.append("first_aid_kit")
            items.append("bandage")
            items.append("medicine")
            if random.nextDouble() < 0.6 {
                items.append("painkiller")
            }

        case .pharmacy:
            // 药店：医疗用品
            items.append("medicine")
            items.append("bandage")
            if random.nextDouble() < 0.7 {
                items.append("painkiller")
            }

        case .gasStation:
            // 加油站：工具和少量补给
            items.append("scrap_metal")
            if random.nextDouble() < 0.6 {
                items.append("flashlight")
            }
            if random.nextDouble() < 0.5 {
                items.append("rope")
            }

        case .warehouse:
            // 仓库：材料为主
            items.append("wood")
            items.append("scrap_metal")
            if random.nextDouble() < 0.6 {
                items.append("cloth")
            }
            if random.nextDouble() < 0.4 {
                items.append("electronics")
            }

        case .factory:
            // 工厂：材料和工具
            items.append("scrap_metal")
            items.append("wood")
            if random.nextDouble() < 0.5 {
                items.append("electronics")
            }
            if random.nextDouble() < 0.4 {
                items.append("rope")
            }

        case .residence, .policeStation, .fireStation:
            // 其他类型：随机物资
            items.append("cloth")
            items.append("wood")
        }

        return items
    }
}
