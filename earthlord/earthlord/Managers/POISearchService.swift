//
//  POISearchService.swift
//  earthlord
//
//  真实 POI 搜索服务
//  使用 MKLocalSearch API 搜索附近的真实地点并转换为游戏 POI
//

import Foundation
import MapKit
import CoreLocation

/// POI 搜索服务
/// 负责搜索附近的真实地点并转换为游戏中的 POI 数据
@MainActor
class POISearchService {

    // MARK: - 单例

    static let shared = POISearchService()

    private init() {}

    // MARK: - 常量

    /// 最大搜索结果数量
    private let maxResults = 30

    /// 测试模式：强制使用程序生成（用于测试，默认 false）
    private let forceProceduralGeneration = false

    /// Apple POI 类型到游戏 POI 类型的映射
    private let poiTypeMapping: [MKPointOfInterestCategory: POIType] = [
        .hospital: .hospital,
        .pharmacy: .pharmacy,
        .gasStation: .gasStation,
        .store: .supermarket,
        .foodMarket: .supermarket,
        .police: .policeStation,
        .fireStation: .fireStation,
        .bank: .warehouse,
        .atm: .warehouse,
        .parking: .gasStation,
        .hotel: .residence,
        .restaurant: .supermarket,
        .cafe: .supermarket,
        .bakery: .supermarket,
        .school: .warehouse,
        .university: .warehouse,
        .library: .warehouse,
        .museum: .warehouse,
        .theater: .warehouse,
        .stadium: .warehouse,
        .laundry: .residence,
        .postOffice: .warehouse,
        .publicTransport: .gasStation,
    ]

    /// 末日风格名称前缀
    private let apocalypseNamePrefixes = [
        "废弃的", "荒废的", "破败的", "遗弃的", "被遗忘的",
        "坍塌的", "残破的", "幸存者的", "末日后的", "劫后余生的"
    ]

    /// 末日风格描述模板
    private let apocalypseDescriptions: [POIType: [String]] = [
        .hospital: [
            "曾经救死扶伤的地方，现在只剩下空荡的病房和残留的医疗物资",
            "废弃的医院，走廊里回荡着诡异的寂静，也许还能找到有用的药品",
            "这里曾是生命的希望所在，如今只有破碎的玻璃和遗弃的医疗设备"
        ],
        .pharmacy: [
            "药店的招牌已经褪色，但货架后面可能还有幸存的药物",
            "破碎的橱窗后，也许能找到急需的医疗用品",
            "虽然已被多次搜刮，但仍可能遗漏了一些珍贵的药品"
        ],
        .gasStation: [
            "加油站的油罐早已干涸，但便利店里可能还有物资",
            "废弃的加油站，汽油味早已消散，却可能藏着有用的工具",
            "锈迹斑斑的加油机旁，散落着被遗弃的物资"
        ],
        .supermarket: [
            "超市的货架大多已空，但角落里可能还有被遗忘的物资",
            "曾经熙熙攘攘的地方，如今只剩下翻倒的购物车和散落的商品",
            "幸存者们已搜刮过多次，但仓库深处也许还有惊喜"
        ],
        .policeStation: [
            "警局的铁门紧闭，但里面可能有珍贵的装备和武器",
            "法律和秩序已成过去，但这里的装备可能帮助你存活",
            "虽然警员早已撤离，武器库里可能还有剩余的装备"
        ],
        .fireStation: [
            "消防站的警铃再也不会响起，但这里有实用的工具和装备",
            "消防员们的储物柜里，可能还有急救包和工具",
            "这里曾是英雄的驻地，留下的装备可能救你一命"
        ],
        .factory: [
            "工厂的机器已经生锈停转，但材料和工具可能还有剩余",
            "空旷的车间里，或许能找到制作所需的材料",
            "虽然危险重重，但工厂里的物资值得冒险一探"
        ],
        .warehouse: [
            "仓库里堆满了灰尘覆盖的箱子，也许能找到有用的东西",
            "这里曾存放着各种货物，现在成了寻宝的好地方",
            "昏暗的仓库里，每一个角落都可能藏着惊喜"
        ],
        .residence: [
            "这栋住宅已无人居住，但厨房和储物间可能有些存粮",
            "曾经温馨的家园，现在成了废墟，但可能有日用品遗留",
            "空荡的房间里，也许能找到前主人留下的物资"
        ]
    ]

    // MARK: - 公开方法

    /// 搜索附近的真实 POI，如果结果不足则使用程序生成
    /// - Parameters:
    ///   - center: 搜索中心坐标
    ///   - radius: 搜索半径（米）
    ///   - maxCount: 最大返回数量（nil 表示使用默认值 maxResults）
    /// - Returns: (POI列表, 来源类型) 元组
    func searchNearbyPOIs(center: CLLocationCoordinate2D, radius: Double = 1000.0, maxCount: Int? = nil) async throws -> (pois: [POI], source: POISource) {
        let effectiveMaxCount = maxCount ?? maxResults
        print("🔍🔍🔍 [POI搜索] ========== 开始搜索 ==========")
        print("🔍 [POI搜索] 用户位置: (\(String(format: "%.6f", center.latitude)), \(String(format: "%.6f", center.longitude)))")
        print("🔍 [POI搜索] 搜索半径: \(radius)m, 目标数量: \(effectiveMaxCount)")

        var allPOIs: [POI] = []
        var searchSuccessCount = 0
        var searchFailCount = 0

        // 搜索多个类别的 POI
        let categoriesToSearch: [MKPointOfInterestCategory] = [
            .hospital, .pharmacy, .gasStation, .store, .foodMarket,
            .police, .fireStation, .bank, .hotel, .restaurant,
            .cafe, .bakery, .parking, .school, .library
        ]

        for category in categoriesToSearch {
            do {
                let request = MKLocalPointsOfInterestRequest(center: center, radius: radius)
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])

                let search = MKLocalSearch(request: request)
                let response = try await search.start()

                searchSuccessCount += 1

                // 转换搜索结果为游戏 POI
                for item in response.mapItems {
                    if let poi = convertToPOI(mapItem: item, center: center) {
                        allPOIs.append(poi)
                    }
                }

                if response.mapItems.count > 0 {
                    print("   ✅ \(category.rawValue): 找到 \(response.mapItems.count) 个")
                }

            } catch {
                searchFailCount += 1
                // 单个类别搜索失败不影响其他类别
                print("   ❌ \(category.rawValue) 搜索失败: \(error.localizedDescription)")
            }
        }

        print("🔍 [POI搜索] API调用统计: 成功=\(searchSuccessCount), 失败=\(searchFailCount)")
        print("🔍 [POI搜索] 原始结果: \(allPOIs.count) 个POI")

        // 去重（根据坐标近似度）
        let uniquePOIs = deduplicatePOIs(allPOIs)

        // 限制数量并按距离排序
        let sortedPOIs = uniquePOIs
            .sorted { ($0.distance ?? Double.infinity) < ($1.distance ?? Double.infinity) }
            .prefix(effectiveMaxCount)

        print("🔍 [POI搜索] 去重后: \(sortedPOIs.count) 个唯一 POI（目标: \(effectiveMaxCount)）")

        // 判断是否有足够的 Apple Maps POI（≥3 个，降低阈值以适应中国区域）
        let appleMapsPOIs = Array(sortedPOIs)
        if !forceProceduralGeneration && appleMapsPOIs.count >= 3 {
            // 足够的真实 POI，标记为 Apple Maps 来源
            // 根据目标数量限制返回数量
            let limitedPOIs = Array(appleMapsPOIs.prefix(effectiveMaxCount))
            let markedPOIs = limitedPOIs.map { markAsAppleMaps($0) }
            print("🔍 [POI搜索] ✅ 使用 Apple Maps POI，共 \(markedPOIs.count) 个（目标: \(effectiveMaxCount)）")
            for (index, poi) in markedPOIs.enumerated() {
                print("   \(index + 1). \(poi.name) - 距离: \(String(format: "%.0f", poi.distance ?? 0))m")
            }
            return (markedPOIs, .appleMaps)
        }

        // 否则，使用程序生成
        let reason = forceProceduralGeneration
            ? "测试模式强制使用"
            : "Apple Maps 结果不足（\(appleMapsPOIs.count) < 3）"
        print("⚠️ [POI搜索] \(reason)，使用程序生成")

        let proceduralPOIs = ProceduralPOIGenerator.shared.generatePOIs(
            around: center,
            radius: radius,
            maxCount: effectiveMaxCount
        )

        print("🔍 [POI搜索] ✅ 程序生成 \(proceduralPOIs.count) 个 POI（目标: \(effectiveMaxCount)）")
        for (index, poi) in proceduralPOIs.enumerated() {
            // 计算与用户的距离
            let distance = calculateDistance(from: center, to: poi.coordinate)
            print("   \(index + 1). \(poi.name) - 距离: \(String(format: "%.0f", distance))m")
        }
        print("🔍🔍🔍 [POI搜索] ========== 搜索完成 ==========")

        return (proceduralPOIs, .procedural)
    }

    /// 标记 POI 来源为 Apple Maps
    private func markAsAppleMaps(_ poi: POI) -> POI {
        var updated = poi
        updated.source = .appleMaps
        updated.geohash = nil
        updated.generatedAt = nil
        return updated
    }

    // MARK: - 私有方法

    /// 将 MKMapItem 转换为游戏 POI
    private func convertToPOI(mapItem: MKMapItem, center: CLLocationCoordinate2D) -> POI? {
        // iOS 26+ 使用 mapItem.location，回退到 placemark.location
        let location: CLLocation?
        if #available(iOS 26.0, *) {
            location = mapItem.location
        } else {
            location = mapItem.placemark.location
        }

        guard let location = location else { return nil }

        // 获取 POI 类型
        let poiType = getGamePOIType(from: mapItem)

        // 生成末日风格名称
        let apocalypseName = generateApocalypseName(
            originalName: mapItem.name ?? "未知地点",
            type: poiType
        )

        // 生成末日风格描述
        let description = generateApocalypseDescription(type: poiType)

        // 计算距离
        let distance = calculateDistance(from: center, to: location.coordinate)

        // 生成可拾取物品列表（基于 POI 类型）
        let lootItems = generateLootItems(for: poiType)

        // 创建 POI（暂时不设置 source，在外层统一设置）
        let poi = POI(
            id: UUID(),
            name: apocalypseName,
            type: poiType,
            coordinate: location.coordinate,
            location: location.coordinate,
            status: .discovered,  // 搜索到的 POI 默认为已发现
            discoveredAt: Date(),
            lootItems: lootItems,
            availableLoot: lootItems,  // 初始时所有物品都可拾取
            dangerLevel: Int.random(in: 1...4),
            description: description,
            distance: distance,
            source: .appleMaps,  // 来自 Apple Maps
            geohash: nil,
            generatedAt: nil
        )

        print("✅ [POI转换] 创建: \(poi.name) at (\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))), 距离: \(String(format: "%.0f", distance))m")

        return poi
    }

    /// 获取游戏 POI 类型
    private func getGamePOIType(from mapItem: MKMapItem) -> POIType {
        if let category = mapItem.pointOfInterestCategory,
           let gameType = poiTypeMapping[category] {
            return gameType
        }

        // 根据名称关键词推断类型
        let name = mapItem.name?.lowercased() ?? ""

        if name.contains("医院") || name.contains("hospital") || name.contains("诊所") || name.contains("clinic") {
            return .hospital
        }
        if name.contains("药") || name.contains("pharmacy") || name.contains("drug") {
            return .pharmacy
        }
        if name.contains("加油") || name.contains("gas") || name.contains("oil") || name.contains("petrol") {
            return .gasStation
        }
        if name.contains("超市") || name.contains("市场") || name.contains("便利") || name.contains("store") || name.contains("market") || name.contains("mart") {
            return .supermarket
        }
        if name.contains("警") || name.contains("police") || name.contains("公安") {
            return .policeStation
        }
        if name.contains("消防") || name.contains("fire") {
            return .fireStation
        }
        if name.contains("工厂") || name.contains("factory") || name.contains("制造") {
            return .factory
        }

        // 默认为仓库类型
        return .warehouse
    }

    /// 生成末日风格名称
    private func generateApocalypseName(originalName: String, type: POIType) -> String {
        let prefix = apocalypseNamePrefixes.randomElement() ?? "废弃的"

        // 如果原名称已经包含类型关键词，直接加前缀
        let typeKeywords = ["医院", "药店", "加油站", "超市", "警局", "消防站", "工厂", "仓库", "商店", "便利店"]
        for keyword in typeKeywords {
            if originalName.contains(keyword) {
                return "\(prefix)\(originalName)"
            }
        }

        // 否则，使用类型名称 + 原名称
        return "\(prefix)\(type.rawValue)「\(originalName)」"
    }

    /// 生成末日风格描述
    private func generateApocalypseDescription(type: POIType) -> String {
        if let descriptions = apocalypseDescriptions[type] {
            return descriptions.randomElement() ?? "这里可能有物资"
        }
        return "这个地方值得探索一番，也许能找到有用的东西"
    }

    /// 计算两点之间的距离
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    /// 根据 POI 类型生成可拾取物品列表
    private func generateLootItems(for type: POIType) -> [String] {
        switch type {
        case .hospital:
            return ["first_aid_kit", "bandage", "medicine", "painkiller"]
        case .pharmacy:
            return ["medicine", "bandage", "painkiller"]
        case .gasStation:
            return ["scrap_metal", "rope", "cloth", "flashlight"]
        case .supermarket:
            return ["water_bottle", "canned_food", "biscuit", "energy_bar"]
        case .policeStation:
            return ["flashlight", "rope", "first_aid_kit", "knife"]
        case .fireStation:
            return ["rope", "flashlight", "first_aid_kit", "cloth"]
        case .factory:
            return ["scrap_metal", "electronics", "wood", "rope"]
        case .warehouse:
            return ["wood", "scrap_metal", "cloth", "rope"]
        case .residence:
            return ["water_bottle", "canned_food", "cloth", "flashlight"]
        }
    }

    /// POI 去重（基于坐标近似度）
    private func deduplicatePOIs(_ pois: [POI]) -> [POI] {
        var uniquePOIs: [POI] = []
        let minDistance: Double = 20.0  // 20米内视为同一地点

        for poi in pois {
            let isDuplicate = uniquePOIs.contains { existingPOI in
                let distance = calculateDistance(
                    from: poi.coordinate,
                    to: existingPOI.coordinate
                )
                return distance < minDistance
            }

            if !isDuplicate {
                uniquePOIs.append(poi)
            }
        }

        return uniquePOIs
    }
}

// MARK: - MKPointOfInterestCategory 扩展

extension MKPointOfInterestCategory {
    /// 获取分类的中文名称
    var chineseName: String {
        switch self {
        case .hospital: return "医院"
        case .pharmacy: return "药店"
        case .gasStation: return "加油站"
        case .store: return "商店"
        case .foodMarket: return "食品市场"
        case .police: return "警察局"
        case .fireStation: return "消防站"
        case .bank: return "银行"
        case .atm: return "ATM"
        case .parking: return "停车场"
        case .hotel: return "酒店"
        case .restaurant: return "餐厅"
        case .cafe: return "咖啡馆"
        case .bakery: return "面包店"
        case .school: return "学校"
        case .university: return "大学"
        case .library: return "图书馆"
        case .museum: return "博物馆"
        case .theater: return "剧院"
        case .stadium: return "体育场"
        case .laundry: return "洗衣店"
        case .postOffice: return "邮局"
        case .publicTransport: return "公共交通"
        default: return "其他"
        }
    }
}
