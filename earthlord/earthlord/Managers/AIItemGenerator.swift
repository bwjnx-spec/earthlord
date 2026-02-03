//
//  AIItemGenerator.swift
//  earthlord
//
//  AI 物品生成器 - 调用 Supabase Edge Function 生成随机物品
//  功能:
//  1. 调用 generate-ai-item Edge Function
//  2. 基于 POI 危险值确定物品稀有度
//  3. 提供降级方案（AI 失败时使用本地随机生成）
//

import Foundation

// MARK: - 请求/响应模型

/// AI 物品生成请求
struct AIGenerateItemRequest: Encodable {
    let poi_name: String
    let poi_type: String
    let danger_level: Int
    let item_count: Int
}

/// AI 物品生成响应
struct AIGenerateItemResponse: Decodable {
    let items: [AIGeneratedItem]
    let error: String?
}

/// AI 生成的单个物品
struct AIGeneratedItem: Decodable {
    let name: String
    let category: String
    let rarity: String
    let rarity_cn: String
    let story: String
    let quantity: Int
    let quality: String
}

// MARK: - AI 物品生成器

/// AI 物品生成器
/// 负责调用 Supabase Edge Function 生成 AI 物品
class AIItemGenerator {

    // MARK: - 单例

    static let shared = AIItemGenerator()

    // MARK: - 配置

    /// Supabase 项目 URL
    private let supabaseURL = "https://xlhkojuliphmvmzhpgzw.supabase.co"

    /// Supabase Anon Key (公开的 publishable key)
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhsaGtvanVsaXBobXZtemhwZ3p3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY3NTMzNDQsImV4cCI6MjA4MjMyOTM0NH0.N7qA8yDBThqn1IwsgsJ808_onrmp91qg1CiTsOBJMaY"

    /// Edge Function 名称
    private let functionName = "generate-ai-item"

    // MARK: - 稀有度分布（用于本地降级）

    /// 基于危险值的稀有度分布
    private let rarityDistribution: [Int: [String: Int]] = [
        1: ["common": 70, "uncommon": 25, "rare": 5, "epic": 0, "legendary": 0],
        2: ["common": 70, "uncommon": 25, "rare": 5, "epic": 0, "legendary": 0],
        3: ["common": 50, "uncommon": 30, "rare": 15, "epic": 5, "legendary": 0],
        4: ["common": 0, "uncommon": 40, "rare": 35, "epic": 20, "legendary": 5],
        5: ["common": 0, "uncommon": 0, "rare": 30, "epic": 40, "legendary": 30]
    ]

    // MARK: - 初始化

    private init() {}

    // MARK: - 公开方法

    /// 为 POI 生成 AI 物品
    /// - Parameters:
    ///   - poi: 目标 POI
    ///   - itemCount: 物品数量（默认 1-4 个）
    /// - Returns: 生成的物品列表
    func generateItems(for poi: POI, itemCount: Int? = nil) async -> [InventoryItem] {
        let count = itemCount ?? Int.random(in: 1...4)

        print("🤖 [AI物品] 为 \(poi.name) 生成 \(count) 个物品，危险值: \(poi.dangerLevel)")

        // 尝试调用 Edge Function
        do {
            let aiItems = try await callEdgeFunction(
                poiName: poi.name,
                poiType: poi.type.rawValue,
                dangerLevel: poi.dangerLevel,
                itemCount: count
            )

            if !aiItems.isEmpty {
                print("✅ [AI物品] 成功从 AI 获取 \(aiItems.count) 个物品")
                return convertToInventoryItems(aiItems: aiItems, poiName: poi.name)
            } else {
                print("⚠️ [AI物品] AI 返回空列表，使用本地降级方案")
                return generateFallbackItems(for: poi, count: count)
            }
        } catch {
            print("❌ [AI物品] Edge Function 调用失败: \(error.localizedDescription)")
            print("⚠️ [AI物品] 使用本地降级方案")
            return generateFallbackItems(for: poi, count: count)
        }
    }

    // MARK: - 私有方法

    /// 调用 Edge Function
    private func callEdgeFunction(
        poiName: String,
        poiType: String,
        dangerLevel: Int,
        itemCount: Int
    ) async throws -> [AIGeneratedItem] {
        // 构建 URL
        guard let url = URL(string: "\(supabaseURL)/functions/v1/\(functionName)") else {
            throw AIItemError.invalidURL
        }

        // 构建请求体
        let requestBody = AIGenerateItemRequest(
            poi_name: poiName,
            poi_type: poiType,
            danger_level: dangerLevel,
            item_count: itemCount
        )

        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = 30.0

        print("🌐 [AI物品] 调用 Edge Function: \(url.absoluteString)")

        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)

        // 检查响应状态
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIItemError.invalidResponse
        }

        print("🌐 [AI物品] 响应状态码: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            throw AIItemError.httpError(statusCode: httpResponse.statusCode)
        }

        // 解析响应
        let decoder = JSONDecoder()
        let aiResponse = try decoder.decode(AIGenerateItemResponse.self, from: data)

        if let error = aiResponse.error, !error.isEmpty {
            print("⚠️ [AI物品] 服务端返回错误: \(error)")
        }

        return aiResponse.items
    }

    /// 将 AI 物品转换为 InventoryItem
    private func convertToInventoryItems(aiItems: [AIGeneratedItem], poiName: String) -> [InventoryItem] {
        return aiItems.map { aiItem in
            InventoryItem(
                id: UUID(),
                definitionId: "ai_generated_\(UUID().uuidString.prefix(8))",
                quantity: aiItem.quantity,
                quality: qualityFromString(aiItem.quality),
                obtainedAt: Date(),
                obtainedFrom: poiName,
                isAIGenerated: true,
                aiName: aiItem.name,
                aiStory: aiItem.story,
                aiCategory: aiItem.category,
                aiRarity: aiItem.rarity
            )
        }
    }

    /// 字符串转品质枚举
    private func qualityFromString(_ string: String) -> ItemQuality {
        switch string {
        case "pristine": return .pristine
        case "good": return .good
        case "worn": return .worn
        case "damaged": return .damaged
        case "broken": return .broken
        default: return .good
        }
    }

    // MARK: - 降级方案

    /// 生成本地降级物品（当 AI 不可用时使用）
    private func generateFallbackItems(for poi: POI, count: Int) -> [InventoryItem] {
        print("📦 [AI物品-降级] 使用本地随机生成 \(count) 个物品")

        var items: [InventoryItem] = []

        for _ in 0..<count {
            // 基于 POI 可用物资或随机选择
            let itemId: String
            if !poi.availableLoot.isEmpty {
                itemId = poi.availableLoot.randomElement() ?? "water_bottle"
            } else {
                // 随机选择一个物品定义
                itemId = MockExplorationData.itemDefinitions.randomElement()?.id ?? "water_bottle"
            }

            // 随机数量
            let quantity = Int.random(in: 1...3)

            // 随机品质
            let quality = ItemQuality.allCases.randomElement() ?? .good

            let item = InventoryItem(
                id: UUID(),
                definitionId: itemId,
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

            items.append(item)
        }

        print("📦 [AI物品-降级] 生成完成，共 \(items.count) 个物品")
        return items
    }

    /// 基于危险值生成稀有度
    private func generateRarity(dangerLevel: Int) -> String {
        let distribution = rarityDistribution[min(max(dangerLevel, 1), 5)] ?? rarityDistribution[1]!
        let roll = Int.random(in: 0..<100)
        var cumulative = 0

        for (rarity, chance) in distribution.sorted(by: { $0.key < $1.key }) {
            cumulative += chance
            if roll < cumulative {
                return rarity
            }
        }

        return "common"
    }
}

// MARK: - 错误类型

enum AIItemError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError
    case aiError(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 API URL"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let statusCode):
            return "HTTP 错误: \(statusCode)"
        case .decodingError:
            return "响应解析失败"
        case .aiError(let message):
            return "AI 错误: \(message)"
        }
    }
}
