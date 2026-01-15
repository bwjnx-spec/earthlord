//
//  MapTabView.swift
//  earthlord
//
//  地图页面 - 显示末世风格地图和用户定位
//

import SwiftUI
import MapKit

struct MapTabView: View {
    // MARK: - State

    /// 定位管理器
    @StateObject private var locationManager = LocationManager()

    /// 用户位置坐标
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否需要重新居中
    @State private var shouldRecenter = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 地图视图
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser,
                shouldRecenter: $shouldRecenter
            )
            .ignoresSafeArea()

            // 覆盖层 UI
            VStack {
                Spacer()

                // 底部控制栏
                HStack {
                    Spacer()

                    // 定位按钮
                    locationButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100) // 避开 TabBar
            }

            // 定位权限被拒绝时的提示卡片
            if locationManager.isDenied {
                permissionDeniedCard
            }

            // 加载指示器
            if !hasLocatedUser && locationManager.isAuthorized {
                loadingOverlay
            }
        }
        .onAppear {
            handleOnAppear()
        }
    }

    // MARK: - Subviews

    /// 定位按钮
    private var locationButton: some View {
        Button(action: {
            recenterToUserLocation()
        }) {
            Image(systemName: "location.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(locationManager.isAuthorized ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                .frame(width: 44, height: 44)
                .background(ApocalypseTheme.cardBackground.opacity(0.95))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(!locationManager.isAuthorized)
    }

    /// 权限被拒绝提示卡片
    private var permissionDeniedCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.warning)

            Text("需要定位权限")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("请在系统设置中开启定位权限，以便在末日世界中显示您的位置")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                openSettings()
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("前往设置")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.primary)
                .cornerRadius(10)
            }
        }
        .padding(24)
        .background(ApocalypseTheme.cardBackground.opacity(0.95))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .padding(32)
    }

    /// 加载覆盖层
    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.2)

            Text("正在定位...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(20)
        .background(ApocalypseTheme.cardBackground.opacity(0.9))
        .cornerRadius(12)
    }

    // MARK: - Actions

    /// 页面出现时的处理
    private func handleOnAppear() {
        print("🗺️ MapTabView 出现")

        // 检查授权状态
        if locationManager.isNotDetermined {
            // 首次使用，请求权限
            print("   首次请求定位权限")
            locationManager.requestPermission()
        } else if locationManager.isAuthorized {
            // 已授权，开始定位
            print("   已授权，开始定位")
            locationManager.startUpdatingLocation()
        } else if locationManager.isDenied {
            // 已拒绝
            print("   定位权限已被拒绝")
        }
    }

    /// 重新居中到用户位置
    private func recenterToUserLocation() {
        guard locationManager.isAuthorized else {
            print("⚠️ 未授权定位")
            return
        }

        if let _ = userLocation {
            print("📍 重新居中到用户位置")
            shouldRecenter = true
        } else {
            print("⚠️ 尚未获得用户位置")
            locationManager.startUpdatingLocation()
        }
    }

    /// 打开系统设置
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
}
