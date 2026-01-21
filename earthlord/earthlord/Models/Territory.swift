//
//  Territory.swift
//  earthlord
//
//  Created on 2025/01/19.
//

import Foundation
import CoreLocation

/// 领地数据模型
/// 用于解析数据库返回的领地数据
struct Territory: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String?              // 可选，数据库允许为空
    let path: [[String: Double]]   // 格式：[{"lat": x, "lon": y}]
    let area: Double
    let pointCount: Int?
    let isActive: Bool?
    let completedAt: String?       // 完成时间
    let startedAt: String?         // 开始时间
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case path
        case area
        case pointCount = "point_count"
        case isActive = "is_active"
        case completedAt = "completed_at"
        case startedAt = "started_at"
        case createdAt = "created_at"
    }

    // MARK: - Initialization

    /// 标准初始化器
    init(id: String, userId: String, name: String?, path: [[String: Double]], area: Double, pointCount: Int?, isActive: Bool?, completedAt: String?, startedAt: String?, createdAt: Date?) {
        self.id = id
        self.userId = userId
        self.name = name
        self.path = path
        self.area = area
        self.pointCount = pointCount
        self.isActive = isActive
        self.completedAt = completedAt
        self.startedAt = startedAt
        self.createdAt = createdAt
    }

    // MARK: - Custom Decoding

    /// 自定义解码器
    /// 处理 Supabase 将 numeric 类型序列化为字符串的问题
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        path = try container.decode([[String: Double]].self, forKey: .path)

        // ⚠️ 关键：处理 area 字段（可能是字符串或数字）
        if let areaString = try? container.decode(String.self, forKey: .area) {
            // 数据库返回的是字符串 "100.00"
            area = Double(areaString) ?? 0.0
        } else {
            // 如果是数字类型（理论上不会发生，但保险起见）
            area = try container.decode(Double.self, forKey: .area)
        }

        pointCount = try container.decodeIfPresent(Int.self, forKey: .pointCount)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
        startedAt = try container.decodeIfPresent(String.self, forKey: .startedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    /// 将 path 转换为 CLLocationCoordinate2D 数组
    /// - Returns: 坐标点数组
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    /// 格式化面积显示
    var formattedArea: String {
        if area >= 1_000_000 {
            return String(format: "%.2f km²", area / 1_000_000)
        } else {
            return String(format: "%.0f m²", area)
        }
    }

    /// 显示名称（如果没有名称则返回默认值）
    var displayName: String {
        return name ?? "未命名领地"
    }
}
