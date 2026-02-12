//
//  TradeManager.swift
//  earthlord
//
//  交易管理器 - 处理玩家间异步挂单交易
//  功能：发布挂单、接受交易、取消挂单、评价、懒过期
//

import Foundation
import Combine
import Supabase

/// 交易管理器
@MainActor
class TradeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = TradeManager()

    // MARK: - Published Properties

    /// 我发布的挂单
    @Published var myOffers: [TradeOffer] = []

    /// 市场可用挂单（排除自己的）
    @Published var availableOffers: [TradeOffer] = []

    /// 交易历史
    @Published var tradeHistory: [TradeHistory] = []

    /// 加载状态
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String? = nil

    // MARK: - Private Properties

    private let supabase: SupabaseClient

    // MARK: - Initialization

    nonisolated init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    private convenience init() {
        self.init(supabase: supabaseClient)
    }

    // MARK: - 创建挂单

    /// 发布交易挂单
    /// - Parameters:
    ///   - offeringItems: 出售的物品列表
    ///   - requestingItems: 求购的物品列表
    ///   - expirationHours: 过期时间（小时），默认24小时
    ///   - message: 留言（可选）
    func createTradeOffer(
        offeringItems: [TradeItem],
        requestingItems: [TradeItem],
        expirationHours: Int = 24,
        message: String? = nil
    ) async throws {
        // 1. 获取用户 ID
        let userId: UUID
        do {
            let session = try await supabase.auth.session
            userId = session.user.id
        } catch {
            throw TradeError.notAuthenticated
        }

        // 2. 验证背包物品充足
        let resources = getCurrentResources()
        var missing: [String: Int] = [:]
        for item in offeringItems {
            let owned = resources[item.itemId] ?? 0
            if owned < item.quantity {
                missing[item.itemId] = item.quantity - owned
            }
        }
        if !missing.isEmpty {
            throw TradeError.insufficientItems(missing: missing)
        }

        // 3. 扣除物品
        deductItems(offeringItems)

        // 4. 构建数据并插入 Supabase
        let expiresAt = Date().addingTimeInterval(TimeInterval(expirationHours * 3600))
        let formatter = ISO8601DateFormatter()

        let data: [String: AnyJSON] = [
            "creator_id": .string(userId.uuidString),
            "offering_items": encodeTradeItemsToAnyJSON(offeringItems),
            "requesting_items": encodeTradeItemsToAnyJSON(requestingItems),
            "status": .string("active"),
            "message": message != nil ? .string(message!) : .null,
            "expires_at": .string(formatter.string(from: expiresAt))
        ]

        do {
            let response: TradeOffer = try await supabase
                .from("trade_offers")
                .insert(data)
                .select()
                .single()
                .execute()
                .value

            myOffers.insert(response, at: 0)
            NotificationCenter.default.post(name: .tradeOffersUpdated, object: nil)
            print("✅ 发布交易挂单成功: \(response.id)")

        } catch {
            // 回滚物品
            rollbackItems(offeringItems)
            print("❌ 发布交易挂单失败，已回滚物品: \(error)")
            throw TradeError.networkError(underlying: error)
        }
    }

    // MARK: - 接受交易

    /// 接受交易挂单
    /// - Parameter offerId: 挂单 ID
    func acceptTradeOffer(offerId: UUID) async throws {
        // 1. 获取用户 ID
        let userId: UUID
        do {
            let session = try await supabase.auth.session
            userId = session.user.id
        } catch {
            throw TradeError.notAuthenticated
        }

        // 2. 查找挂单
        guard let offer = availableOffers.first(where: { $0.id == offerId })
                ?? myOffers.first(where: { $0.id == offerId }) else {
            throw TradeError.offerNotFound
        }

        // 3. 验证
        guard offer.status == .active else {
            throw TradeError.offerNotActive
        }
        guard !offer.isExpired else {
            throw TradeError.offerExpired
        }
        guard offer.creatorId != userId else {
            throw TradeError.cannotAcceptOwnOffer
        }

        // 4. 验证接受者背包有请求的物品
        let resources = getCurrentResources()
        var missing: [String: Int] = [:]
        for item in offer.requestingItems {
            let owned = resources[item.itemId] ?? 0
            if owned < item.quantity {
                missing[item.itemId] = item.quantity - owned
            }
        }
        if !missing.isEmpty {
            throw TradeError.insufficientItems(missing: missing)
        }

        // 5. 扣除接受者的物品（offer 请求的物品）
        deductItems(offer.requestingItems)

        // 6. 更新 Supabase 挂单状态
        let formatter = ISO8601DateFormatter()
        let now = Date()

        do {
            try await supabase
                .from("trade_offers")
                .update([
                    "status": AnyJSON.string("completed"),
                    "acceptor_id": AnyJSON.string(userId.uuidString),
                    "completed_at": AnyJSON.string(formatter.string(from: now))
                ])
                .eq("id", value: offerId.uuidString)
                .execute()

            // 7. 添加挂单提供的物品到接受者背包
            addItemsToInventory(offer.offeringItems, source: "交易获得")

            // 8. 插入交易历史
            let historyData: [String: AnyJSON] = [
                "offer_id": .string(offerId.uuidString),
                "seller_id": .string(offer.creatorId.uuidString),
                "buyer_id": .string(userId.uuidString),
                "offering_items": encodeTradeItemsToAnyJSON(offer.offeringItems),
                "requesting_items": encodeTradeItemsToAnyJSON(offer.requestingItems),
                "completed_at": .string(formatter.string(from: now))
            ]

            let history: TradeHistory = try await supabase
                .from("trade_history")
                .insert(historyData)
                .select()
                .single()
                .execute()
                .value

            tradeHistory.insert(history, at: 0)

            // 9. 更新本地缓存
            availableOffers.removeAll { $0.id == offerId }
            if let index = myOffers.firstIndex(where: { $0.id == offerId }) {
                myOffers[index].status = .completed
                myOffers[index].acceptorId = userId
                myOffers[index].completedAt = now
            }

            // 10. 发送通知
            NotificationCenter.default.post(name: .tradeCompleted, object: nil)
            NotificationCenter.default.post(name: .tradeOffersUpdated, object: nil)
            print("✅ 交易完成: \(offerId)")

        } catch {
            // 回滚接受者的物品
            rollbackItems(offer.requestingItems)
            print("❌ 接受交易失败，已回滚物品: \(error)")
            throw TradeError.networkError(underlying: error)
        }
    }

    // MARK: - 取消挂单

    /// 取消交易挂单
    /// - Parameter offerId: 挂单 ID
    func cancelTradeOffer(offerId: UUID) async throws {
        // 1. 获取用户 ID
        let userId: UUID
        do {
            let session = try await supabase.auth.session
            userId = session.user.id
        } catch {
            throw TradeError.notAuthenticated
        }

        // 2. 查找挂单
        guard let offer = myOffers.first(where: { $0.id == offerId }) else {
            throw TradeError.offerNotFound
        }

        // 3. 验证
        guard offer.creatorId == userId else {
            throw TradeError.cannotCancelOthersOffer
        }
        guard offer.status == .active else {
            throw TradeError.offerNotActive
        }

        // 4. 更新 Supabase 状态
        do {
            try await supabase
                .from("trade_offers")
                .update(["status": AnyJSON.string("cancelled")])
                .eq("id", value: offerId.uuidString)
                .execute()

            // 5. 恢复物品到背包
            rollbackItems(offer.offeringItems)

            // 6. 更新本地缓存
            if let index = myOffers.firstIndex(where: { $0.id == offerId }) {
                myOffers[index].status = .cancelled
            }

            NotificationCenter.default.post(name: .tradeOffersUpdated, object: nil)
            print("✅ 挂单已取消，物品已退还: \(offerId)")

        } catch {
            print("❌ 取消挂单失败: \(error)")
            throw TradeError.networkError(underlying: error)
        }
    }

    // MARK: - 数据加载

    /// 加载我发布的挂单
    func loadMyOffers() async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.session
            let userId = session.user.id

            let response: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("creator_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            myOffers = response
            print("✅ 加载了 \(response.count) 个我的挂单")
        } catch {
            errorMessage = "加载挂单失败: \(error.localizedDescription)"
            print("❌ 加载我的挂单失败: \(error)")
        }

        isLoading = false
    }

    /// 加载市场可用挂单（排除自己的，仅 active 且未过期）
    func loadAvailableOffers() async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            let formatter = ISO8601DateFormatter()
            let nowString = formatter.string(from: Date())

            let response: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("status", value: "active")
                .neq("creator_id", value: userId.uuidString)
                .gte("expires_at", value: nowString)
                .order("created_at", ascending: false)
                .execute()
                .value

            availableOffers = response
            print("✅ 加载了 \(response.count) 个可用挂单")
        } catch {
            errorMessage = "加载市场失败: \(error.localizedDescription)"
            print("❌ 加载可用挂单失败: \(error)")
        }

        isLoading = false
    }

    /// 加载交易历史
    func loadTradeHistory() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [TradeHistory] = try await supabase
                .from("trade_history")
                .select()
                .order("completed_at", ascending: false)
                .execute()
                .value

            tradeHistory = response
            print("✅ 加载了 \(response.count) 条交易历史")
        } catch {
            errorMessage = "加载交易历史失败: \(error.localizedDescription)"
            print("❌ 加载交易历史失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 评价

    /// 评价交易
    /// - Parameters:
    ///   - historyId: 交易历史 ID
    ///   - rating: 评分 (1-5)
    ///   - comment: 评语（可选）
    func rateTrade(historyId: UUID, rating: Int, comment: String? = nil) async throws {
        // 1. 验证评分范围
        guard rating >= 1 && rating <= 5 else {
            throw TradeError.invalidRating
        }

        // 2. 获取用户 ID
        let userId: UUID
        do {
            let session = try await supabase.auth.session
            userId = session.user.id
        } catch {
            throw TradeError.notAuthenticated
        }

        // 3. 查找交易历史
        guard let history = tradeHistory.first(where: { $0.id == historyId }) else {
            throw TradeError.offerNotFound
        }

        // 4. 判断角色并更新
        let isSeller = history.sellerId == userId
        let isBuyer = history.buyerId == userId

        if isSeller {
            guard history.sellerRating == nil else {
                throw TradeError.alreadyRated
            }

            var updateData: [String: AnyJSON] = [
                "seller_rating": .integer(rating)
            ]
            if let comment = comment {
                updateData["seller_comment"] = .string(comment)
            }

            try await supabase
                .from("trade_history")
                .update(updateData)
                .eq("id", value: historyId.uuidString)
                .execute()

            if let index = tradeHistory.firstIndex(where: { $0.id == historyId }) {
                tradeHistory[index].sellerRating = rating
                tradeHistory[index].sellerComment = comment
            }

        } else if isBuyer {
            guard history.buyerRating == nil else {
                throw TradeError.alreadyRated
            }

            var updateData: [String: AnyJSON] = [
                "buyer_rating": .integer(rating)
            ]
            if let comment = comment {
                updateData["buyer_comment"] = .string(comment)
            }

            try await supabase
                .from("trade_history")
                .update(updateData)
                .eq("id", value: historyId.uuidString)
                .execute()

            if let index = tradeHistory.firstIndex(where: { $0.id == historyId }) {
                tradeHistory[index].buyerRating = rating
                tradeHistory[index].buyerComment = comment
            }

        } else {
            throw TradeError.offerNotFound
        }

        print("✅ 评价成功: \(historyId), 评分: \(rating)")
    }

    // MARK: - 懒过期检查

    /// 检查并过期自己的过期挂单
    func checkAndExpireOffers() async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            let formatter = ISO8601DateFormatter()
            let nowString = formatter.string(from: Date())

            // 查询自己的 active 且已过期的挂单
            let expiredOffers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("creator_id", value: userId.uuidString)
                .eq("status", value: "active")
                .lt("expires_at", value: nowString)
                .execute()
                .value

            for offer in expiredOffers {
                // 更新状态为 expired
                try await supabase
                    .from("trade_offers")
                    .update(["status": AnyJSON.string("expired")])
                    .eq("id", value: offer.id.uuidString)
                    .execute()

                // 退还物品
                rollbackItems(offer.offeringItems)

                // 更新本地缓存
                if let index = myOffers.firstIndex(where: { $0.id == offer.id }) {
                    myOffers[index].status = .expired
                }

                print("✅ 挂单已过期，物品已退还: \(offer.id)")
            }

            if !expiredOffers.isEmpty {
                NotificationCenter.default.post(name: .tradeOffersUpdated, object: nil)
            }
        } catch {
            print("❌ 过期检查失败: \(error)")
        }
    }

    // MARK: - Private 辅助方法

    /// 获取当前背包资源统计
    private func getCurrentResources() -> [String: Int] {
        var resources: [String: Int] = [:]
        for item in ExplorationManager.shared.inventoryItems {
            resources[item.definitionId, default: 0] += item.quantity
        }
        return resources
    }

    /// 从背包扣除物品
    private func deductItems(_ items: [TradeItem]) {
        for tradeItem in items {
            var remaining = tradeItem.quantity
            for i in (0..<ExplorationManager.shared.inventoryItems.count).reversed() {
                guard ExplorationManager.shared.inventoryItems[i].definitionId == tradeItem.itemId else { continue }
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

    /// 退还物品到背包
    private func rollbackItems(_ items: [TradeItem]) {
        for tradeItem in items {
            let item = InventoryItem(
                id: UUID(),
                definitionId: tradeItem.itemId,
                quantity: tradeItem.quantity,
                quality: nil,
                obtainedAt: Date(),
                obtainedFrom: "交易退还"
            )
            ExplorationManager.shared.addItemToInventory(item: item)
        }
    }

    /// 添加交易获得的物品到背包
    private func addItemsToInventory(_ items: [TradeItem], source: String) {
        for tradeItem in items {
            let item = InventoryItem(
                id: UUID(),
                definitionId: tradeItem.itemId,
                quantity: tradeItem.quantity,
                quality: nil,
                obtainedAt: Date(),
                obtainedFrom: source
            )
            ExplorationManager.shared.addItemToInventory(item: item)
        }
    }

    /// 将 TradeItem 数组编码为 AnyJSON
    private func encodeTradeItemsToAnyJSON(_ items: [TradeItem]) -> AnyJSON {
        .array(items.map { item in
            .object([
                "item_id": .string(item.itemId),
                "quantity": .integer(item.quantity)
            ])
        })
    }
}
