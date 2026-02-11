//
//  MapViewRepresentable.swift
//  earthlord
//
//  MKMapView 的 SwiftUI 包装器 - 显示末世风格的苹果地图
//  扩展支持路径轨迹渲染（圈地模式）和 POI 标注显示
//

import SwiftUI
import MapKit

/// MKMapView 的 SwiftUI 包装器
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - Bindings

    /// 用户位置坐标
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @Binding var hasLocatedUser: Bool

    /// 是否需要重新居中到用户位置
    @Binding var shouldRecenter: Bool

    /// 路径坐标数组（用于轨迹渲染）
    @Binding var trackingPath: [CLLocationCoordinate2D]

    /// 路径更新版本号（触发轨迹刷新）
    @Binding var pathUpdateVersion: Int

    /// 路径是否已闭合
    @Binding var isPathClosed: Bool

    /// 已保存的领地列表
    var territories: [Territory]

    /// 领地更新版本号（触发重绘）
    @Binding var territoriesVersion: Int

    /// 当前用户 ID（用于区分我的领地和他人领地）
    var currentUserId: String?

    // MARK: - POI 相关

    /// POI 列表
    var pois: [POI]

    /// POI 版本号（触发 POI 标注更新）
    @Binding var poisVersion: Int

    /// POI 点击回调
    var onPOITapped: ((POI) -> Void)?

    // MARK: - UIViewRepresentable

    /// 创建 MKMapView
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 配置地图类型（卫星图+道路标签，符合末世废土风格）
        mapView.mapType = .hybrid

        // 隐藏 POI 标签（商店、餐厅等）
        mapView.pointOfInterestFilter = .excludingAll

        // 隐藏3D建筑
        mapView.showsBuildings = false

        // 显示用户位置蓝点 ⚠️ 关键！
        mapView.showsUserLocation = true

        // 允许用户交互
        mapView.isZoomEnabled = true      // 允许缩放
        mapView.isScrollEnabled = true    // 允许拖动
        mapView.isRotateEnabled = true    // 允许旋转
        mapView.isPitchEnabled = true     // 允许倾斜

        // 设置代理 ⚠️ 关键！否则 didUpdate userLocation 不会被调用
        mapView.delegate = context.coordinator

        // 注册 POI 标注视图
        mapView.register(POIAnnotationView.self, forAnnotationViewWithReuseIdentifier: POIAnnotationView.reuseIdentifier)

        // 应用末世滤镜效果
        applyApocalypseFilter(to: mapView)

        // 设置初始区域（默认显示中国）
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
            latitudinalMeters: 5000000,
            longitudinalMeters: 5000000
        )
        mapView.setRegion(initialRegion, animated: false)

        print("🗺️ MKMapView 创建完成")
        return mapView
    }

    /// 更新 MKMapView
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 处理重新居中请求
        if shouldRecenter, let location = userLocation {
            let region = MKCoordinateRegion(
                center: location,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: true)

            // 重置标志
            DispatchQueue.main.async {
                shouldRecenter = false
            }
        }

        // 模拟器回退：如果首次获得位置但 delegate 没有触发居中，主动居中
        #if targetEnvironment(simulator)
        if !context.coordinator.hasInitialCenteredFromUpdate,
           let location = userLocation {
            print("📍 [模拟器] 检测到位置更新，主动居中地图")
            context.coordinator.hasInitialCenteredFromUpdate = true

            let region = MKCoordinateRegion(
                center: location,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: true)

            DispatchQueue.main.async {
                self.hasLocatedUser = true
            }
        }
        #endif

        // 更新路径轨迹（检测版本变化）
        if context.coordinator.lastPathVersion != pathUpdateVersion {
            context.coordinator.lastPathVersion = pathUpdateVersion
            updatePathOverlay(mapView: mapView, context: context)
        }

        // 更新已保存的领地（检测版本变化）
        if context.coordinator.lastTerritoriesVersion != territoriesVersion {
            print("🗺️ 检测到领地版本变化: \(context.coordinator.lastTerritoriesVersion) -> \(territoriesVersion)")
            context.coordinator.lastTerritoriesVersion = territoriesVersion
            drawTerritories(mapView: mapView, context: context)
        }

        // 更新 POI 标注（检测版本变化或数量变化）
        let currentPOICount = pois.count
        if context.coordinator.lastPOIsVersion != poisVersion ||
           context.coordinator.lastPOICount != currentPOICount {
            print("📍 检测到 POI 变化:")
            print("   - 版本: \(context.coordinator.lastPOIsVersion) -> \(poisVersion)")
            print("   - 数量: \(context.coordinator.lastPOICount) -> \(currentPOICount)")
            context.coordinator.lastPOIsVersion = poisVersion
            context.coordinator.lastPOICount = currentPOICount
            updatePOIAnnotations(mapView: mapView, context: context)
        }
    }

    /// 更新 POI 标注
    private func updatePOIAnnotations(mapView: MKMapView, context: Context) {
        print("📍 [POI标注] 开始更新...")
        print("📍 [地图] 当前pois数量: \(pois.count)")
        print("📍 [地图] 准备添加 \(pois.count) 个标注")

        // 移除旧的 POI 标注
        let existingPOIAnnotations = mapView.annotations.compactMap { $0 as? POIAnnotation }
        print("📍 [POI标注] 移除旧标注: \(existingPOIAnnotations.count) 个")
        mapView.removeAnnotations(existingPOIAnnotations)

        // 添加新的 POI 标注
        var addedCount = 0
        for poi in pois {
            let annotation = POIAnnotation(poi: poi)
            mapView.addAnnotation(annotation)
            addedCount += 1
            print("📍 [POI标注] 添加: \(poi.name) at (\(String(format: "%.6f", poi.coordinate.latitude)), \(String(format: "%.6f", poi.coordinate.longitude))), 距离: \(poi.distance.map { String(format: "%.0f", $0) + "m" } ?? "未知")")
        }

        print("✅ [POI标注] 更新完成，共添加 \(addedCount) 个标注")
        print("📍 [POI标注] 地图当前总标注数: \(mapView.annotations.count)")

        // 打印地图可见区域信息（用于诊断标注是否在可见区域内）
        let region = mapView.region
        print("📍 [地图] 可见区域中心: (\(String(format: "%.6f", region.center.latitude)), \(String(format: "%.6f", region.center.longitude)))")
        print("📍 [地图] 可见区域跨度: 纬度±\(String(format: "%.6f", region.span.latitudeDelta/2)), 经度±\(String(format: "%.6f", region.span.longitudeDelta/2))")
    }

    /// 更新路径覆盖层（当前正在圈的路径）
    private func updatePathOverlay(mapView: MKMapView, context: Context) {
        // 只移除追踪路径相关的覆盖层，保留已保存的领地
        let trackingOverlays = mapView.overlays.filter { overlay in
            // 已保存领地的 overlay 存储在 coordinator 中
            !context.coordinator.territoryOverlays.contains(where: { $0 === overlay })
        }
        mapView.removeOverlays(trackingOverlays)

        // 如果有足够的点，添加新的路径
        guard trackingPath.count >= 2 else {
            print("🗺️ 路径点不足(\(trackingPath.count)个)，跳过渲染")
            return
        }

        // 创建折线
        var coords = trackingPath
        let polyline = MKPolyline(coordinates: &coords, count: coords.count)

        // ⚠️ 关键：使用 aboveRoads 层级确保轨迹显示在地图上方
        mapView.addOverlay(polyline, level: .aboveRoads)

        // 如果路径已闭合且点数 >= 3，添加多边形填充
        if isPathClosed && trackingPath.count >= 3 {
            var polygonCoords = trackingPath
            let polygon = MKPolygon(coordinates: &polygonCoords, count: polygonCoords.count)
            mapView.addOverlay(polygon, level: .aboveRoads)
            print("🗺️ 多边形填充已添加")
        }

        print("🗺️ 路径轨迹已更新，共 \(trackingPath.count) 个点，闭合状态: \(isPathClosed)")
        if !trackingPath.isEmpty {
            print("   首点: (\(String(format: "%.6f", trackingPath[0].latitude)), \(String(format: "%.6f", trackingPath[0].longitude)))")
        }
    }

    /// 绘制已保存的领地
    private func drawTerritories(mapView: MKMapView, context: Context) {
        print("🗺️ ========== 开始绘制已保存的领地 ==========")
        print("🗺️ 领地数量: \(territories.count)")
        print("🗺️ 当前用户 ID: \(currentUserId ?? "nil")")
        print("🗺️ 地图当前区域: center=(\(mapView.region.center.latitude), \(mapView.region.center.longitude))")

        // 移除旧的领地覆盖层
        print("🗺️ 移除旧的领地覆盖层: \(context.coordinator.territoryOverlays.count) 个")
        mapView.removeOverlays(context.coordinator.territoryOverlays)
        context.coordinator.territoryOverlays.removeAll()

        // 绘制每个领地
        for (index, territory) in territories.enumerated() {
            print("\n🗺️ --- 处理领地 \(index + 1)/\(territories.count) ---")
            print("🗺️ 领地 ID: \(territory.id)")
            print("🗺️ 领地名称: \(territory.name ?? "未命名")")
            print("🗺️ 用户 ID: \(territory.userId)")

            let coordinates = territory.toCoordinates()
            print("🗺️ 原始坐标数量: \(coordinates.count)")

            guard coordinates.count >= 3 else {
                print("⚠️ 领地坐标点不足 (\(coordinates.count) < 3)，跳过")
                continue
            }

            // 打印坐标（数据库中已经是 GCJ-02，不需要再转换）
            if !coordinates.isEmpty {
                print("🗺️ 首点坐标: (\(coordinates[0].latitude), \(coordinates[0].longitude))")
            }

            // ⚠️ 注意：数据库存的已经是 GCJ-02 坐标（LocationManager 采集时已转换）
            // 所以这里不需要再转换，直接使用即可
            // coordinates = CoordinateConverter.wgs84ToGcj02(coordinates)  // ❌ 多余的转换已移除

            // 创建多边形
            var coords = coordinates
            let polygon = MKPolygon(coordinates: &coords, count: coords.count)

            // ⚠️ 关键：比较 userId 时必须统一大小写！
            let isMine = territory.userId.lowercased() == currentUserId?.lowercased()
            polygon.title = isMine ? "mine" : "others"

            print("🗺️ userId 比较: '\(territory.userId.lowercased())' == '\(currentUserId?.lowercased() ?? "nil")' -> \(isMine)")
            print("🗺️ polygon.title = \(polygon.title ?? "nil")")

            // 添加到地图
            mapView.addOverlay(polygon, level: .aboveRoads)
            print("🗺️ ✅ 多边形已添加到地图")

            // 记录到 coordinator
            context.coordinator.territoryOverlays.append(polygon)
        }

        print("\n🗺️ ========== 领地绘制完成 ==========")
        print("🗺️ 总共添加了 \(context.coordinator.territoryOverlays.count) 个领地覆盖层")
        print("🗺️ 地图当前覆盖层总数: \(mapView.overlays.count)")
    }

    /// 创建 Coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Private Methods

    /// 应用末世滤镜效果（降低饱和度、添加棕褐色调）
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 注意：iOS 的 CALayer.filters 在真机上可能不生效
        // 这里使用覆盖层来实现滤镜效果

        // 创建一个半透明的覆盖视图来模拟滤镜
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 0.15)
        overlayView.isUserInteractionEnabled = false  // 不拦截触摸事件
        overlayView.translatesAutoresizingMaskIntoConstraints = false

        mapView.addSubview(overlayView)

        // 设置覆盖视图约束（覆盖整个地图）
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: mapView.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: mapView.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: mapView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: mapView.trailingAnchor)
        ])

        print("🎨 末世滤镜已应用")
    }

    // MARK: - Coordinator

    /// Coordinator 类 - 处理 MKMapView 代理回调
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable

        /// 首次居中标志 - 防止重复居中（delegate 触发）
        private var hasInitialCentered = false

        /// 首次居中标志 - 防止重复居中（updateUIView 触发，用于模拟器回退）
        var hasInitialCenteredFromUpdate = false

        /// 上次路径版本号（用于检测变化）
        var lastPathVersion: Int = 0

        /// 上次领地版本号（用于检测变化）
        var lastTerritoriesVersion: Int = 0

        /// 上次 POI 版本号（用于检测变化）
        var lastPOIsVersion: Int = 0

        /// 上次 POI 数量（用于检测变化）
        var lastPOICount: Int = 0

        /// 领地覆盖层数组（用于跟踪已绘制的领地）
        var territoryOverlays: [MKPolygon] = []

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate

        /// ⭐ 关键方法：用户位置更新时调用
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置
            guard let location = userLocation.location else { return }

            // 更新绑定的位置
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            // 首次获得位置时，自动居中地图
            guard !hasInitialCentered else { return }

            print("📍 首次获得用户位置，自动居中地图")

            // 创建居中区域（约1公里范围）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )

            // 平滑居中地图
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }
        }

        /// 地图区域变化完成
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可以在这里处理地图移动后的逻辑
        }

        /// 地图加载完成
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            print("🗺️ 地图加载完成")
        }

        /// 地图加载失败
        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
            print("❌ 地图加载失败: \(error.localizedDescription)")
        }

        /// 标注视图（POI 和用户位置）
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置使用默认蓝点
            if annotation is MKUserLocation {
                return nil
            }

            // POI 标注
            if let poiAnnotation = annotation as? POIAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: POIAnnotationView.reuseIdentifier,
                    for: annotation
                ) as? POIAnnotationView ?? POIAnnotationView(annotation: annotation, reuseIdentifier: POIAnnotationView.reuseIdentifier)

                view.annotation = poiAnnotation
                view.configure(with: poiAnnotation)

                return view
            }

            return nil
        }

        /// POI 标注 Callout 按钮点击
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let poiAnnotation = view.annotation as? POIAnnotation else { return }

            print("📍 POI 点击: \(poiAnnotation.poi.name)")

            // 调用回调
            parent.onPOITapped?(poiAnnotation.poi)
        }

        /// ⭐ 关键方法：轨迹渲染器（必须实现否则轨迹不显示）
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            print("🎨 rendererFor 被调用，overlay 类型: \(type(of: overlay))")

            // 处理折线渲染
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                if parent.isPathClosed {
                    // 闭合路径：绿色实线
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 6.0
                    print("🎨 渲染闭合路径，绿色实线")
                } else {
                    // 追踪中：青色实线
                    renderer.strokeColor = UIColor.systemCyan
                    renderer.lineWidth = 5.0
                    print("🎨 渲染追踪路径，青色实线")
                }

                return renderer
            }

            // 处理多边形渲染
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 根据领地所有者设置颜色
                if polygon.title == "mine" {
                    // 我的领地：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    print("🎨 渲染我的领地，绿色半透明")
                } else if polygon.title == "others" {
                    // 他人领地：橙色
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemOrange
                    print("🎨 渲染他人领地，橙色半透明")
                } else {
                    // 默认：绿色（用于追踪中的多边形）
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    print("🎨 渲染多边形填充，绿色半透明")
                }

                renderer.lineWidth = 2.0
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Preview

#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        hasLocatedUser: .constant(false),
        shouldRecenter: .constant(false),
        trackingPath: .constant([]),
        pathUpdateVersion: .constant(0),
        isPathClosed: .constant(false),
        territories: [],
        territoriesVersion: .constant(0),
        currentUserId: nil,
        pois: [],
        poisVersion: .constant(0),
        onPOITapped: nil
    )
}
