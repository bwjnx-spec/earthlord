//
//  POIAnnotation.swift
//  earthlord
//
//  POI 标注模型
//  实现 MKAnnotation 协议，用于在地图上显示 POI 标记
//

import Foundation
import MapKit

/// POI 标注类
/// 用于在地图上显示 POI 信息
class POIAnnotation: NSObject, MKAnnotation {

    // MARK: - Properties

    /// POI 数据
    let poi: POI

    /// 标注坐标（MKAnnotation 协议要求）
    /// 【重要】使用 GCJ-02 坐标用于地图显示，解决中国地图漂移问题
    var coordinate: CLLocationCoordinate2D {
        // 将 POI 的 WGS-84 坐标转换为 GCJ-02 用于 Apple Maps 显示
        CoordinateConverter.wgs84ToGcj02(poi.coordinate)
    }

    /// 标注标题（显示 POI 名称）
    var title: String? {
        poi.name
    }

    /// 标注副标题（显示距离）
    var subtitle: String? {
        if let distance = poi.distance {
            if distance >= 1000 {
                return String(format: "%.1f 公里", distance / 1000)
            } else {
                return String(format: "%.0f 米", distance)
            }
        }
        return nil
    }

    // MARK: - Computed Properties

    /// POI 类型图标名称
    var iconName: String {
        switch poi.type {
        case .hospital:
            return "cross.case.fill"
        case .pharmacy:
            return "pills.fill"
        case .gasStation:
            return "fuelpump.fill"
        case .supermarket:
            return "cart.fill"
        case .policeStation:
            return "shield.fill"
        case .fireStation:
            return "flame.fill"
        case .factory:
            return "gearshape.2.fill"
        case .warehouse:
            return "shippingbox.fill"
        case .residence:
            return "house.fill"
        }
    }

    /// POI 类型颜色
    var typeColor: UIColor {
        switch poi.type {
        case .hospital:
            return UIColor.systemRed
        case .pharmacy:
            return UIColor.systemGreen
        case .gasStation:
            return UIColor.systemOrange
        case .supermarket:
            return UIColor.systemBlue
        case .policeStation:
            return UIColor.systemIndigo
        case .fireStation:
            return UIColor.systemRed
        case .factory:
            return UIColor.systemGray
        case .warehouse:
            return UIColor.systemBrown
        case .residence:
            return UIColor.systemTeal
        }
    }

    /// 是否可以搜刮（状态为已发现或有物资）
    var isLootable: Bool {
        poi.status == .discovered || poi.status == .hasLoot
    }

    /// 是否已搜刮完毕
    var isLooted: Bool {
        poi.status == .looted
    }

    /// 根据状态返回透明度
    var opacity: CGFloat {
        switch poi.status {
        case .undiscovered:
            return 0.3
        case .discovered, .hasLoot:
            return 1.0
        case .looted:
            return 0.5
        case .dangerous:
            return 0.8
        }
    }

    // MARK: - Initialization

    init(poi: POI) {
        self.poi = poi
        super.init()
    }
}
