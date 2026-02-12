//
//  TradeModels.swift
//  earthlord
//
//  交易系统数据模型
//

import Foundation

// MARK: - TradeOfferStatus

/// 交易挂单状态
enum TradeOfferStatus: String, Codable, CaseIterable {
    case active = "active"
    case completed = "completed"
    case cancelled = "cancelled"
    case expired = "expired"

    var displayName: String {
        switch self {
        case .active: return "挂单中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        case .expired: return "已过期"
        }
    }
}

// MARK: - TradeItem

/// 交易物品条目
struct TradeItem: Codable, Identifiable, Equatable {
    var id: String { itemId }
    let itemId: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case quantity
    }

    /// 物品中文名称
    var displayName: String {
        MockExplorationData.getItemDefinition(by: itemId)?.name ?? itemId
    }
}

// MARK: - TradeOffer

/// 交易挂单
struct TradeOffer: Codable, Identifiable {
    let id: UUID
    let creatorId: UUID
    let offeringItems: [TradeItem]
    let requestingItems: [TradeItem]
    var status: TradeOfferStatus
    var acceptorId: UUID?
    let message: String?
    let expiresAt: Date
    var completedAt: Date?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case status
        case acceptorId = "acceptor_id"
        case message
        case expiresAt = "expires_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 是否已过期
    var isExpired: Bool {
        Date() > expiresAt
    }

    /// 是否可被接受
    var isAcceptable: Bool {
        status == .active && !isExpired
    }

    /// 剩余时间（秒）
    var remainingTime: TimeInterval {
        max(0, expiresAt.timeIntervalSinceNow)
    }

    /// 格式化的剩余时间
    var formattedRemainingTime: String {
        let seconds = Int(remainingTime)
        if seconds <= 0 { return "已过期" }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟"
        } else {
            return "\(seconds)秒"
        }
    }
}

// MARK: - TradeHistory

/// 交易历史记录
struct TradeHistory: Codable, Identifiable {
    let id: UUID
    let offerId: UUID
    let sellerId: UUID
    let buyerId: UUID
    let offeringItems: [TradeItem]
    let requestingItems: [TradeItem]
    var sellerRating: Int?
    var buyerRating: Int?
    var sellerComment: String?
    var buyerComment: String?
    let completedAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case buyerId = "buyer_id"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case sellerRating = "seller_rating"
        case buyerRating = "buyer_rating"
        case sellerComment = "seller_comment"
        case buyerComment = "buyer_comment"
        case completedAt = "completed_at"
        case createdAt = "created_at"
    }
}

// MARK: - TradeError

/// 交易错误类型
enum TradeError: LocalizedError {
    case notAuthenticated
    case insufficientItems(missing: [String: Int])
    case offerNotFound
    case offerExpired
    case offerNotActive
    case cannotAcceptOwnOffer
    case cannotCancelOthersOffer
    case alreadyRated
    case invalidRating
    case networkError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "未登录，请先登录"
        case .insufficientItems(let missing):
            let items = missing.map { key, value in
                let name = MockExplorationData.getItemDefinition(by: key)?.name ?? key
                return "\(name) x\(value)"
            }.joined(separator: "、")
            return "背包物品不足，缺少：\(items)"
        case .offerNotFound:
            return "交易挂单不存在"
        case .offerExpired:
            return "交易挂单已过期"
        case .offerNotActive:
            return "交易挂单已失效"
        case .cannotAcceptOwnOffer:
            return "不能接受自己的挂单"
        case .cannotCancelOthersOffer:
            return "不能取消他人的挂单"
        case .alreadyRated:
            return "已经评价过了"
        case .invalidRating:
            return "评分无效，请输入1-5之间的数字"
        case .networkError(let underlying):
            return "网络错误：\(underlying.localizedDescription)"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let tradeCompleted = Notification.Name("tradeCompleted")
    static let tradeOffersUpdated = Notification.Name("tradeOffersUpdated")
}
