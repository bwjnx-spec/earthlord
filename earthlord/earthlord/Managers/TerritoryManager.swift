//
//  TerritoryManager.swift
//  earthlord
//
//  Created on 2025/01/19.
//

import Foundation
import Combine
import CoreLocation
import Supabase

/// 领地管理器
/// 负责领地数据的上传和拉取
@MainActor
class TerritoryManager: ObservableObject {

    // MARK: - Published Properties

    /// 所有领地列表
    @Published var territories: [Territory] = []

    /// 加载状态
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String? = nil

    // MARK: - Private Properties

    private let supabase: SupabaseClient
    private let logger = TerritoryLogger.shared

    // MARK: - Initialization

    init(supabase: SupabaseClient = supabaseClient) {
        self.supabase = supabase
    }

    // MARK: - 坐标转换方法

    /// 将坐标数组转换为 path JSON 格式
    /// - Parameter coordinates: CLLocationCoordinate2D 数组
    /// - Returns: [{"lat": x, "lon": y}, ...] 格式的数组
    func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coord in
            ["lat": coord.latitude, "lon": coord.longitude]
        }
    }

    /// 将坐标数组转换为 WKT 格式
    /// - Parameter coordinates: CLLocationCoordinate2D 数组
    /// - Returns: WKT 多边形字符串，格式：SRID=4326;POLYGON((lon lat, lon lat, ...))
    /// - Note: WKT 格式是「经度在前，纬度在后」，多边形必须闭合
    func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        guard coordinates.count >= 3 else {
            print("❌ WKT 转换失败：坐标点不足 3 个")
            return ""
        }

        // 确保多边形闭合（首尾相同）
        var closedCoords = coordinates
        if let first = coordinates.first, let last = coordinates.last {
            if first.latitude != last.latitude || first.longitude != last.longitude {
                closedCoords.append(first)
            }
        }

        // WKT 格式：经度在前，纬度在后
        let pointsString = closedCoords.map { coord in
            "\(coord.longitude) \(coord.latitude)"
        }.joined(separator: ", ")

        return "SRID=4326;POLYGON((\(pointsString)))"
    }

    /// 计算边界框
    /// - Parameter coordinates: CLLocationCoordinate2D 数组
    /// - Returns: (minLat, maxLat, minLon, maxLon) 元组
    func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        guard !coordinates.isEmpty else { return nil }

        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        guard let minLat = lats.min(),
              let maxLat = lats.max(),
              let minLon = lons.min(),
              let maxLon = lons.max() else {
            return nil
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - 上传方法

    /// 上传领地数据到数据库
    /// - Parameters:
    ///   - coordinates: 领地边界坐标点数组
    ///   - area: 领地面积（平方米）
    ///   - startTime: 圈地开始时间
    /// - Throws: 上传失败时抛出错误
    func uploadTerritory(coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date) async throws {
        print("📤 开始上传领地...")
        print("   坐标点数: \(coordinates.count)")
        print("   面积: \(area) 平方米")

        isLoading = true
        errorMessage = nil

        do {
            // 1. 获取当前用户 ID
            let session = try await supabase.auth.session
            let userId = session.user.id

            print("   用户 ID: \(userId.uuidString)")

            // 2. 准备数据
            let pathJSON = coordinatesToPathJSON(coordinates)
            let wktPolygon = coordinatesToWKT(coordinates)

            guard let bbox = calculateBoundingBox(coordinates) else {
                throw TerritoryError.invalidCoordinates
            }

            print("   WKT: \(wktPolygon.prefix(50))...")
            print("   边界框: (\(bbox.minLat), \(bbox.maxLat), \(bbox.minLon), \(bbox.maxLon))")

            // 3. 构建上传数据
            let territoryData: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "path": .array(pathJSON.map { point in
                    .object([
                        "lat": .double(point["lat"] ?? 0),
                        "lon": .double(point["lon"] ?? 0)
                    ])
                }),
                "polygon": .string(wktPolygon),
                "bbox_min_lat": .double(bbox.minLat),
                "bbox_max_lat": .double(bbox.maxLat),
                "bbox_min_lon": .double(bbox.minLon),
                "bbox_max_lon": .double(bbox.maxLon),
                "area": .double(area),
                "point_count": .integer(coordinates.count),
                "is_active": .bool(true)
            ]

            // 4. 插入数据
            print("   正在插入数据库...")
            try await supabase
                .from("territories")
                .insert(territoryData)
                .execute()

            print("✅ 领地上传成功!")

            // 记录成功日志
            logger.log("领地上传成功！面积: \(Int(area))m²", type: .success)

        } catch {
            errorMessage = "上传失败: \(error.localizedDescription)"
            print("❌ 领地上传失败: \(error)")

            // 记录失败日志
            logger.log("领地上传失败: \(error.localizedDescription)", type: .error)

            throw error
        }

        isLoading = false
    }

    // MARK: - 拉取方法

    /// 加载所有活跃的领地
    /// - Returns: 领地数组
    /// - Throws: 加载失败时抛出错误
    func loadAllTerritories() async throws -> [Territory] {
        print("📥 开始加载领地列表...")

        isLoading = true
        errorMessage = nil

        do {
            // 查询 is_active = true 的领地
            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value

            territories = response
            print("✅ 加载成功，共 \(response.count) 个领地")

            isLoading = false
            return response

        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
            print("❌ 加载领地列表失败: \(error)")
            isLoading = false
            throw error
        }
    }

    /// 加载当前用户的领地
    /// - Returns: 当前用户的领地数组
    /// - Throws: 加载失败时抛出错误
    func loadMyTerritories() async throws -> [Territory] {
        print("📥 开始加载我的领地...")

        isLoading = true
        errorMessage = nil

        do {
            // 获取当前用户 ID
            let session = try await supabase.auth.session
            let userId = session.user.id

            // 查询当前用户的活跃领地
            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .execute()
                .value

            print("✅ 加载成功，我的领地共 \(response.count) 个")

            isLoading = false
            return response

        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
            print("❌ 加载我的领地失败: \(error)")
            isLoading = false
            throw error
        }
    }

    /// 删除领地
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 是否删除成功
    func deleteTerritory(territoryId: String) async -> Bool {
        print("🗑️ 开始删除领地: \(territoryId)")

        do {
            try await supabase
                .from("territories")
                .delete()
                .eq("id", value: territoryId)
                .execute()

            print("✅ 领地删除成功")
            logger.log("领地已删除", type: .success)
            return true

        } catch {
            print("❌ 删除领地失败: \(error)")
            logger.log("删除领地失败: \(error.localizedDescription)", type: .error)
            return false
        }
    }

    // MARK: - 碰撞检测算法

    /// 射线法判断点是否在多边形内
    /// - Parameters:
    ///   - point: 待检测的点
    ///   - polygon: 多边形顶点数组
    /// - Returns: true 表示点在多边形内
    func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        let x = point.longitude
        let y = point.latitude

        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }
            j = i
        }

        return inside
    }

    /// 检查起始点是否在他人领地内
    /// - Parameters:
    ///   - location: 待检测的位置
    ///   - currentUserId: 当前用户ID
    /// - Returns: 碰撞检测结果
    func checkPointCollision(location: CLLocationCoordinate2D, currentUserId: String) -> CollisionResult {
        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else {
            return .safe
        }

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()
            guard polygon.count >= 3 else { continue }

            if isPointInPolygon(point: location, polygon: polygon) {
                logger.log("起点碰撞：位于他人领地内", type: .error)
                return CollisionResult(
                    hasCollision: true,
                    collisionType: .pointInTerritory,
                    message: "不能在他人领地内开始圈地！",
                    closestDistance: 0,
                    warningLevel: .violation
                )
            }
        }

        return .safe
    }

    /// 判断两条线段是否相交（CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1的起点
    ///   - p2: 线段1的终点
    ///   - p3: 线段2的起点
    ///   - p4: 线段2的终点
    /// - Returns: true 表示相交
    private func segmentsIntersect(
        p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D
    ) -> Bool {
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            return (C.latitude - A.latitude) * (B.longitude - A.longitude) >
                   (B.latitude - A.latitude) * (C.longitude - A.longitude)
        }

        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检查路径是否穿越他人领地边界
    /// - Parameters:
    ///   - path: 路径坐标数组
    ///   - currentUserId: 当前用户ID
    /// - Returns: 碰撞检测结果
    func checkPathCrossTerritory(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return .safe }

        for i in 0..<(path.count - 1) {
            let pathStart = path[i]
            let pathEnd = path[i + 1]

            for territory in otherTerritories {
                let polygon = territory.toCoordinates()
                guard polygon.count >= 3 else { continue }

                // 检查与领地每条边的相交
                for j in 0..<polygon.count {
                    let boundaryStart = polygon[j]
                    let boundaryEnd = polygon[(j + 1) % polygon.count]

                    if segmentsIntersect(p1: pathStart, p2: pathEnd, p3: boundaryStart, p4: boundaryEnd) {
                        logger.log("路径碰撞：轨迹穿越他人领地边界", type: .error)
                        return CollisionResult(
                            hasCollision: true,
                            collisionType: .pathCrossTerritory,
                            message: "轨迹不能穿越他人领地！",
                            closestDistance: 0,
                            warningLevel: .violation
                        )
                    }
                }

                // 检查路径点是否在领地内
                if isPointInPolygon(point: pathEnd, polygon: polygon) {
                    logger.log("路径碰撞：轨迹点进入他人领地", type: .error)
                    return CollisionResult(
                        hasCollision: true,
                        collisionType: .pointInTerritory,
                        message: "轨迹不能进入他人领地！",
                        closestDistance: 0,
                        warningLevel: .violation
                    )
                }
            }
        }

        return .safe
    }

    /// 计算当前位置到他人领地的最近距离
    /// - Parameters:
    ///   - location: 当前位置
    ///   - currentUserId: 当前用户ID
    /// - Returns: 最近距离（米）
    func calculateMinDistanceToTerritories(location: CLLocationCoordinate2D, currentUserId: String) -> Double {
        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return Double.infinity }

        var minDistance = Double.infinity
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()

            for vertex in polygon {
                let vertexLocation = CLLocation(latitude: vertex.latitude, longitude: vertex.longitude)
                let distance = currentLocation.distance(from: vertexLocation)
                minDistance = min(minDistance, distance)
            }
        }

        return minDistance
    }

    /// 综合碰撞检测（主方法）
    /// - Parameters:
    ///   - path: 路径坐标数组
    ///   - currentUserId: 当前用户ID
    /// - Returns: 碰撞检测结果
    func checkPathCollisionComprehensive(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        // 1. 检查路径是否穿越他人领地
        let crossResult = checkPathCrossTerritory(path: path, currentUserId: currentUserId)
        if crossResult.hasCollision {
            return crossResult
        }

        // 2. 计算到最近领地的距离
        guard let lastPoint = path.last else { return .safe }
        let minDistance = calculateMinDistanceToTerritories(location: lastPoint, currentUserId: currentUserId)

        // 3. 根据距离确定预警级别和消息
        let warningLevel: WarningLevel
        let message: String?

        if minDistance > 100 {
            warningLevel = .safe
            message = nil
        } else if minDistance > 50 {
            warningLevel = .caution
            message = "注意：距离他人领地 \(Int(minDistance))m"
        } else if minDistance > 25 {
            warningLevel = .warning
            message = "警告：正在靠近他人领地（\(Int(minDistance))m）"
        } else {
            warningLevel = .danger
            message = "危险：即将进入他人领地！（\(Int(minDistance))m）"
        }

        if warningLevel != .safe {
            logger.log("距离预警：\(warningLevel.description)，距离 \(Int(minDistance))m", type: .warning)
        }

        return CollisionResult(
            hasCollision: false,
            collisionType: nil,
            message: message,
            closestDistance: minDistance,
            warningLevel: warningLevel
        )
    }
}

// MARK: - 错误类型

enum TerritoryError: LocalizedError {
    case invalidCoordinates
    case uploadFailed(String)
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCoordinates:
            return "无效的坐标数据"
        case .uploadFailed(let message):
            return "上传失败: \(message)"
        case .loadFailed(let message):
            return "加载失败: \(message)"
        }
    }
}
