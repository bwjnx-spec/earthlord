//
//  MapViewRepresentable.swift
//  earthlord
//
//  MKMapView 的 SwiftUI 包装器 - 显示末世风格的苹果地图
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

        /// 首次居中标志 - 防止重复居中
        private var hasInitialCentered = false

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

        /// 用户位置视图（可自定义蓝点样式）
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置使用默认蓝点
            if annotation is MKUserLocation {
                return nil
            }
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        hasLocatedUser: .constant(false),
        shouldRecenter: .constant(false)
    )
}
