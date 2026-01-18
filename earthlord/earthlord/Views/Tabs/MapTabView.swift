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

    /// 是否显示验证结果横幅
    @State private var showValidationBanner = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 地图视图
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser,
                shouldRecenter: $shouldRecenter,
                trackingPath: $locationManager.pathCoordinates,
                pathUpdateVersion: $locationManager.pathUpdateVersion,
                isPathClosed: $locationManager.isPathClosed
            )
            .ignoresSafeArea(edges: .top) // 只忽略顶部安全区域，保留底部 TabBar

            // 覆盖层 UI
            VStack {
                // 顶部验证结果横幅
                if showValidationBanner {
                    validationResultBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 顶部速度警告横幅
                if let warning = locationManager.speedWarning {
                    speedWarningBanner(warning: warning)
                        .padding(.top, showValidationBanner ? 0 : 60) // 如果有验证横幅，就不需要额外间距
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(), value: locationManager.speedWarning)
                }

                Spacer()

                // 底部控制栏
                HStack {
                    // 圈地按钮
                    trackingButton

                    Spacer()

                    // 定位按钮
                    locationButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16) // 在 TabBar 上方留出一点空间
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
        // 监听闭环状态，闭环后根据验证结果显示横幅
        .onReceive(locationManager.$isPathClosed) { isClosed in
            if isClosed {
                // 闭环后延迟一点点，等待验证结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        showValidationBanner = true
                    }
                    // 3 秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showValidationBanner = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    /// 圈地按钮
    private var trackingButton: some View {
        Button(action: {
            toggleTracking()
        }) {
            HStack(spacing: 8) {
                Image(systemName: locationManager.isTracking ? "stop.circle.fill" : "record.circle")
                    .font(.system(size: 18, weight: .medium))

                if locationManager.isTracking {
                    Text("停止圈地")
                        .font(.system(size: 14, weight: .medium))

                    // 显示已记录的点数
                    Text("(\(locationManager.pathCoordinates.count))")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                } else {
                    Text("开始圈地")
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .foregroundColor(locationManager.isTracking ? .white : ApocalypseTheme.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                locationManager.isTracking
                    ? ApocalypseTheme.danger
                    : ApocalypseTheme.cardBackground.opacity(0.95)
            )
            .cornerRadius(22)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(!locationManager.isAuthorized)
        .opacity(locationManager.isAuthorized ? 1.0 : 0.5)
    }

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

    /// 速度警告横幅
    private func speedWarningBanner(warning: String) -> some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: locationManager.isTracking ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)

            // 警告文字
            Text(warning)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            // 根据是否还在追踪选择颜色
            locationManager.isTracking
                ? Color.orange // 警告但继续追踪：橙色
                : Color.red    // 已停止追踪：红色
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)

            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .padding(.top, 50)
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

    /// 切换圈地状态
    private func toggleTracking() {
        if locationManager.isTracking {
            // 停止圈地
            locationManager.stopPathTracking()
            print("🛑 用户停止圈地")
        } else {
            // 开始圈地
            locationManager.startPathTracking()
            print("🏃 用户开始圈地")
        }
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
}
