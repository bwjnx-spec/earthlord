//
//  BuildingModels.swift
//  earthlord
//
//  Created on 2025/01/28.
//

import Foundation
import SwiftUI
import CoreLocation

// MARK: - 建筑分类

enum BuildingCategory: String, Codable, CaseIterable {
    case survival
    case storage
    case production
    case energy

    var displayName: String {
        switch self {
        case .survival: return "生存"
        case .storage: return "仓储"
        case .production: return "生产"
        case .energy: return "能源"
        }
    }

    var icon: String {
        switch self {
        case .survival: return "flame.fill"
        case .storage: return "shippingbox.fill"
        case .production: return "leaf.fill"
        case .energy: return "bolt.fill"
        }
    }
}

// MARK: - 建筑状态

enum BuildingStatus: String, Codable {
    case constructing
    case active

    var displayName: String {
        switch self {
        case .constructing: return "建造中"
        case .active: return "运行中"
        }
    }

    var color: Color {
        switch self {
        case .constructing: return .orange
        case .active: return .green
        }
    }
}

// MARK: - 建筑模板

struct BuildingTemplate: Codable, Identifiable, Equatable {
    let id: UUID
    let templateId: String
    let name: String
    let category: BuildingCategory
    let tier: Int
    let description: String
    let icon: String
    let requiredResources: [String: Int]
    let buildTimeSeconds: Int
    let maxPerTerritory: Int
    let maxLevel: Int

    enum CodingKeys: String, CodingKey {
        case id
        case templateId = "template_id"
        case name
        case category
        case tier
        case description
        case icon
        case requiredResources = "required_resources"
        case buildTimeSeconds = "build_time_seconds"
        case maxPerTerritory = "max_per_territory"
        case maxLevel = "max_level"
    }
}

// MARK: - 玩家建筑（对应数据库表）

struct PlayerBuilding: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let territoryId: UUID
    let templateId: String
    let buildingName: String
    var status: BuildingStatus
    var level: Int
    let locationLat: Double
    let locationLon: Double
    let buildStartedAt: Date
    var buildCompletedAt: Date?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    /// 建造是否已完成（基于时间判断）
    var isConstructionComplete: Bool {
        return status == .active || buildCompletedAt != nil
    }

    /// 剩余建造时间（秒）
    var remainingBuildTime: TimeInterval {
        guard status == .constructing, let completedAt = buildCompletedAt else {
            return 0
        }
        let remaining = completedAt.timeIntervalSince(Date())
        return max(0, remaining)
    }

    /// 建造进度 (0.0 ~ 1.0)
    var buildProgress: Double {
        guard status == .constructing,
              let completedAt = buildCompletedAt else {
            return status == .active ? 1.0 : 0.0
        }
        let totalDuration = completedAt.timeIntervalSince(buildStartedAt)
        guard totalDuration > 0 else { return 1.0 }
        let elapsed = Date().timeIntervalSince(buildStartedAt)
        return min(max(elapsed / totalDuration, 0.0), 1.0)
    }

    /// 建筑坐标（GCJ-02，显示时不做转换）
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: locationLat, longitude: locationLon)
    }

    /// 格式化的剩余建造时间
    var formattedRemainingTime: String {
        let remaining = Int(remainingBuildTime)
        if remaining <= 0 {
            return "即将完成"
        }
        let minutes = remaining / 60
        let seconds = remaining % 60
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        }
        return "\(seconds)秒"
    }
}

// MARK: - 建筑错误

enum BuildingError: LocalizedError {
    case insufficientResources(missing: [String: Int])
    case maxBuildingsReached(templateId: String, max: Int)
    case templateNotFound(templateId: String)
    case invalidStatus(current: BuildingStatus, expected: BuildingStatus)
    case notAuthenticated
    case buildingNotFound(buildingId: UUID)
    case networkError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .insufficientResources(let missing):
            let items = missing.map { "\($0.key) 缺少 \($0.value)" }.joined(separator: ", ")
            return "资源不足: \(items)"
        case .maxBuildingsReached(let templateId, let max):
            return "该领地已达到 \(templateId) 的最大数量(\(max))"
        case .templateNotFound(let templateId):
            return "未找到建筑模板: \(templateId)"
        case .invalidStatus(let current, let expected):
            return "建筑状态错误: 当前 \(current.displayName)，需要 \(expected.displayName)"
        case .notAuthenticated:
            return "用户未登录"
        case .buildingNotFound(let buildingId):
            return "未找到建筑: \(buildingId)"
        case .networkError(let underlying):
            return "网络错误: \(underlying.localizedDescription)"
        }
    }
}
