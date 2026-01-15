//
//  LocationManager.swift
//  earthlord
//
//  GPS 定位管理器 - 负责获取用户位置和管理定位权限
//

import Foundation
import CoreLocation
import Combine  // ⚠️ @Published 需要这个框架

/// GPS 定位管理器
class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    /// 是否正在定位中
    @Published var isLocating: Bool = false

    // MARK: - Private Properties

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

    // MARK: - Computed Properties

    /// 是否已授权定位
    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// 是否被用户拒绝
    var isDenied: Bool {
        authorizationStatus == .denied
    }

    /// 是否尚未决定（首次请求）
    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    // MARK: - Initialization

    override init() {
        // 获取当前授权状态
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 10  // 移动10米才更新位置

        print("📍 LocationManager 初始化完成")
        print("   当前授权状态: \(authorizationStatusDescription)")
    }

    // MARK: - Public Methods

    /// 请求定位权限
    func requestPermission() {
        print("📍 请求定位权限...")
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始更新位置
    func startUpdatingLocation() {
        guard isAuthorized else {
            print("⚠️ 未授权定位，无法开始")
            locationError = "请先授权定位权限"
            return
        }

        print("📍 开始获取位置...")
        isLocating = true
        locationError = nil
        locationManager.startUpdatingLocation()
    }

    /// 停止更新位置
    func stopUpdatingLocation() {
        print("📍 停止获取位置")
        isLocating = false
        locationManager.stopUpdatingLocation()
    }

    /// 请求一次性位置更新
    func requestLocation() {
        guard isAuthorized else {
            print("⚠️ 未授权定位，无法请求位置")
            locationError = "请先授权定位权限"
            return
        }

        print("📍 请求一次性位置...")
        locationError = nil
        locationManager.requestLocation()
    }

    /// 重新居中到用户位置（返回当前位置）
    func getCurrentLocation() -> CLLocationCoordinate2D? {
        return userLocation
    }

    // MARK: - Private Helpers

    /// 授权状态描述
    private var authorizationStatusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "未决定"
        case .restricted:
            return "受限制"
        case .denied:
            return "已拒绝"
        case .authorizedAlways:
            return "始终允许"
        case .authorizedWhenInUse:
            return "使用时允许"
        @unknown default:
            return "未知"
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态变化回调
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let oldStatus = self.authorizationStatus
            self.authorizationStatus = manager.authorizationStatus

            print("📍 授权状态变化: \(self.authorizationStatusDescription)")

            // 如果刚获得授权，自动开始定位
            if self.isAuthorized && oldStatus == .notDetermined {
                print("   ✅ 用户授权成功，开始定位")
                self.startUpdatingLocation()
            }

            // 如果被拒绝，设置错误信息
            if self.isDenied {
                self.locationError = "定位权限被拒绝，请在设置中开启"
            }
        }
    }

    /// 位置更新回调
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        DispatchQueue.main.async { [weak self] in
            self?.userLocation = location.coordinate
            self?.locationError = nil

            print("📍 位置更新: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        }
    }

    /// 定位失败回调
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isLocating = false

            // 处理不同类型的错误
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self?.locationError = "定位权限被拒绝"
                case .locationUnknown:
                    self?.locationError = "无法确定当前位置"
                case .network:
                    self?.locationError = "网络错误，无法定位"
                default:
                    self?.locationError = "定位失败: \(error.localizedDescription)"
                }
            } else {
                self?.locationError = "定位失败: \(error.localizedDescription)"
            }

            print("❌ 定位失败: \(error.localizedDescription)")
        }
    }
}
