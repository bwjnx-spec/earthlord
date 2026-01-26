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

    /// 认证管理器（从环境获取）
    @EnvironmentObject var authManager: AuthManager

    /// 定位管理器
    @StateObject private var locationManager = LocationManager()

    /// 领地管理器
    @StateObject private var territoryManager = TerritoryManager()

    /// 行走奖励管理器
    @StateObject private var walkingRewardManager = WalkingRewardManager.shared

    /// 用户位置坐标
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否需要重新居中
    @State private var shouldRecenter = false

    /// 是否显示验证结果横幅
    @State private var showValidationBanner = false

    /// 是否正在上传领地
    @State private var isUploading = false

    /// 上传结果提示
    @State private var uploadResultMessage: String?

    /// 是否显示上传结果
    @State private var showUploadResult = false

    /// 已加载的领地列表
    @State private var territories: [Territory] = []

    /// 领地版本号（用于触发地图重绘）
    @State private var territoriesVersion = 0

    // MARK: - Day 19: 碰撞检测状态

    /// 追踪开始时间
    @State private var trackingStartTime: Date?

    /// 碰撞检测定时器
    @State private var collisionCheckTimer: Timer?

    /// 碰撞警告消息
    @State private var collisionWarning: String?

    /// 是否显示碰撞警告
    @State private var showCollisionWarning = false

    /// 碰撞警告级别
    @State private var collisionWarningLevel: WarningLevel = .safe

    // MARK: - 探索功能状态

    /// 是否正在探索中
    @State private var isExploring = false

    /// 是否显示探索结果
    @State private var showExplorationResult = false

    /// 当前用户 ID（方便访问）
    private var currentUserId: String? {
        authManager.currentUser?.id
    }

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
                isPathClosed: $locationManager.isPathClosed,
                territories: territories,
                territoriesVersion: $territoriesVersion,
                currentUserId: authManager.currentUser?.id
            )
            .ignoresSafeArea(edges: .top) // 只忽略顶部安全区域，保留底部 TabBar

            // 左上角坐标和行走统计显示 + 右上角成就提示
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        coordinateOverlay
                        walkingStatsOverlay
                    }
                    Spacer()
                    // 右上角成就提示
                    if !walkingRewardManager.pendingAchievementRewards.isEmpty {
                        achievementBadge
                    }
                }
                Spacer()
            }
            .padding(.top, 60)
            .padding(.horizontal, 16)

            // 覆盖层 UI
            VStack {
                // 顶部验证结果横幅
                if showValidationBanner {
                    validationResultBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 上传结果提示横幅
                if showUploadResult, let message = uploadResultMessage {
                    uploadResultBanner(message: message)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 顶部速度警告横幅
                if let warning = locationManager.speedWarning {
                    speedWarningBanner(warning: warning)
                        .padding(.top, showValidationBanner ? 0 : 60) // 如果有验证横幅，就不需要额外间距
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(), value: locationManager.speedWarning)
                }

                // Day 19: 碰撞警告横幅（分级颜色）
                if showCollisionWarning, let warning = collisionWarning {
                    collisionWarningBanner(message: warning, level: collisionWarningLevel)
                }

                Spacer()

                // 「确认登记」按钮 - 只在验证通过时显示
                if locationManager.territoryValidationPassed && !isUploading {
                    confirmRegisterButton
                        .padding(.bottom, 16)
                        .transition(.scale.combined(with: .opacity))
                }

                // 上传中指示器
                if isUploading {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("正在登记领地...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(22)
                    .padding(.bottom, 16)
                }

                // 底部控制栏
                HStack {
                    // 圈地按钮
                    trackingButton

                    Spacer()

                    // 定位按钮
                    locationButton

                    Spacer()

                    // 探索按钮
                    exploreButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16) // 在 TabBar 上方留出一点空间
            }
            .sheet(isPresented: $showExplorationResult) {
                ExplorationResultView(sessionResult: MockExplorationData.mockExplorationSessionResult)
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
            print("\n🗺️ ========== MapTabView.onAppear 被调用 ==========")
            print("🗺️ 用户是否已登录: \(authManager.isAuthenticated)")
            print("🗺️ 当前用户: \(authManager.currentUser?.email ?? "未登录")")

            handleOnAppear()

            // 加载所有领地
            Task {
                await loadTerritories()
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, newValue in
            print("\n🔑 认证状态变化: \(newValue)")
            if newValue {
                // 用户刚登录，重新加载领地
                Task {
                    await loadTerritories()
                }
            }
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

    /// 左上角坐标显示
    private var coordinateOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 标题行
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundColor(locationManager.isAuthorized ? .green : .red)

                Text("GPS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }

            // 坐标数据
            if let location = userLocation {
                Text(String(format: "%.6f", location.latitude))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)

                Text(String(format: "%.6f", location.longitude))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            } else {
                Text("---.------")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))

                Text("---.------")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }

    /// 行走统计显示
    private var walkingStatsOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 标题行
            HStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 10))
                    .foregroundColor(.green)

                Text("行走")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }

            // 今日距离
            HStack(spacing: 4) {
                Text("今日:")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Text(String(format: "%.0fm", locationManager.todayWalkDistance))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }

            // 总距离
            HStack(spacing: 4) {
                Text("总计:")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Text(formatDistance(locationManager.totalWalkDistance))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }

            // 每日目标进度条
            if walkingRewardManager.dailyGoalProgress > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("目标")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Text(String(format: "%.0f%%", walkingRewardManager.dailyGoalProgress * 100))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(walkingRewardManager.dailyGoalAchieved ? .green : .yellow)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 3)

                            // 进度
                            Rectangle()
                                .fill(walkingRewardManager.dailyGoalAchieved ? Color.green : Color.yellow)
                                .frame(width: geometry.size.width * walkingRewardManager.dailyGoalProgress, height: 3)
                        }
                    }
                    .frame(height: 3)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }

    /// 格式化距离显示
    private func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.2fkm", distance / 1000)
        } else {
            return String(format: "%.0fm", distance)
        }
    }

    /// 成就提示徽章
    private var achievementBadge: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.yellow)

                // 数量徽章
                if walkingRewardManager.pendingAchievementRewards.count > 1 {
                    Text("\(walkingRewardManager.pendingAchievementRewards.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }

            Text("成就")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
        .onTapGesture {
            // TODO: 打开成就列表界面
            print("🏆 点击成就徽章，待领取: \(walkingRewardManager.pendingAchievementRewards.count)")
        }
    }

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

    /// 探索按钮
    private var exploreButton: some View {
        Button(action: {
            startExploration()
        }) {
            HStack(spacing: 8) {
                if isExploring {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)

                    Text("探索中...")
                        .font(.system(size: 14, weight: .medium))
                } else {
                    Image(systemName: "binoculars.fill")
                        .font(.system(size: 18, weight: .medium))

                    Text("探索")
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isExploring
                    ? ApocalypseTheme.textMuted
                    : ApocalypseTheme.primary
            )
            .cornerRadius(22)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(isExploring || !locationManager.isAuthorized)
        .opacity(locationManager.isAuthorized ? 1.0 : 0.5)
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

    /// 确认登记按钮
    private var confirmRegisterButton: some View {
        Button(action: {
            Task {
                await uploadCurrentTerritory()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .medium))
                Text("确认登记领地")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.green)
            .cornerRadius(25)
            .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
        }
    }

    /// 上传结果横幅
    private func uploadResultBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: message.contains("成功") ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.body)
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(message.contains("成功") ? Color.green : Color.red)
        .padding(.top, showValidationBanner ? 0 : 50)
    }

    /// Day 19: 碰撞警告横幅（分级颜色）
    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return VStack {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 18))

                Text(message)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundColor.opacity(0.95))
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .padding(.top, 120)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: showCollisionWarning)
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

    /// 开始探索
    private func startExploration() {
        guard !isExploring else { return }

        isExploring = true

        // 模拟1.5秒的搜索过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isExploring = false
            showExplorationResult = true
        }
    }

    /// 切换圈地状态
    private func toggleTracking() {
        if locationManager.isTracking {
            // 停止圈地
            stopCollisionMonitoring()  // Day 19: 完全停止，清除警告
            locationManager.stopPathTracking()
            print("🛑 用户停止圈地")
        } else {
            // Day 19: 开始圈地前检测起始点
            startClaimingWithCollisionCheck()
        }
    }

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        guard let location = locationManager.userLocation,
              let userId = currentUserId else {
            return
        }

        // 检测起始点是否在他人领地内
        let result = territoryManager.checkPointCollision(
            location: location,
            currentUserId: userId
        )

        if result.hasCollision {
            // 起点在他人领地内，显示错误并震动
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)

            TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

            // 3秒后隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }

            return
        }

        // 起点安全，开始圈地
        TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
        trackingStartTime = Date()
        locationManager.startPathTracking()
        startCollisionMonitoring()
    }

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 每 10 秒检测一次
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [self] _ in
            performCollisionCheck()
        }

        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
        TerritoryLogger.shared.log("碰撞检测定时器已停止", type: .info)
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        // 清除警告状态
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        guard locationManager.isTracking,
              let userId = currentUserId else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        let result = territoryManager.checkPathCollisionComprehensive(
            path: path,
            currentUserId: userId
        )

        // 根据预警级别处理
        switch result.warningLevel {
        case .safe:
            // 安全，隐藏警告横幅
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe

        case .caution:
            // 注意（50-100m）- 黄色横幅 + 轻震 1 次
            collisionWarning = result.message
            collisionWarningLevel = .caution
            showCollisionWarning = true
            triggerHapticFeedback(level: .caution)

        case .warning:
            // 警告（25-50m）- 橙色横幅 + 中震 2 次
            collisionWarning = result.message
            collisionWarningLevel = .warning
            showCollisionWarning = true
            triggerHapticFeedback(level: .warning)

        case .danger:
            // 危险（<25m）- 红色横幅 + 强震 3 次
            collisionWarning = result.message
            collisionWarningLevel = .danger
            showCollisionWarning = true
            triggerHapticFeedback(level: .danger)

        case .violation:
            // 【关键修复】违规处理 - 必须先显示横幅，再停止！

            // 1. 先设置警告状态（让横幅显示出来）
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 2. 触发震动
            triggerHapticFeedback(level: .violation)

            // 3. 只停止定时器，不清除警告状态！
            stopCollisionCheckTimer()

            // 4. 停止圈地追踪
            locationManager.stopPathTracking()
            trackingStartTime = nil

            TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

            // 5. 5秒后再清除警告横幅
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }
        }
    }

    /// Day 19: 触发震动反馈
    private func triggerHapticFeedback(level: WarningLevel) {
        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .warning:
            // 警告：中震 2 次
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }

        case .danger:
            // 危险：强震 3 次
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred()
            }

        case .violation:
            // 违规：错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }

    /// 上传当前领地
    private func uploadCurrentTerritory() async {
        print("📤 开始上传领地...")

        // 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            print("❌ 领地验证未通过，无法上传")
            showUploadError("领地验证未通过，无法上传")
            return
        }

        // 检查坐标数据
        guard !locationManager.pathCoordinates.isEmpty else {
            print("❌ 无坐标数据")
            showUploadError("无坐标数据，请重新圈地")
            return
        }

        isUploading = true

        do {
            try await territoryManager.uploadTerritory(
                coordinates: locationManager.pathCoordinates,
                area: locationManager.calculatedArea,
                startTime: Date()
            )

            // 上传成功
            print("✅ 领地上传成功！")
            showUploadSuccess("领地登记成功！面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")

            // Day 19: 上传成功后停止追踪并重置状态
            stopCollisionMonitoring()  // 完全停止，清除警告
            locationManager.stopPathTracking()

            // 重新加载领地以显示新上传的领地
            await loadTerritories()

        } catch {
            // 上传失败
            print("❌ 领地上传失败: \(error.localizedDescription)")
            showUploadError("上传失败: \(error.localizedDescription)")
        }

        isUploading = false
    }

    /// 加载所有领地
    private func loadTerritories() async {
        print("\n📥 ========== 开始加载领地 ==========")
        print("📥 认证状态: \(authManager.isAuthenticated)")
        print("📥 当前用户: \(authManager.currentUser?.email ?? "未登录")")
        print("📥 当前用户 ID: \(authManager.currentUser?.id ?? "nil")")

        // 如果用户未登录，跳过加载
        guard authManager.isAuthenticated else {
            print("⚠️ 用户未登录，跳过领地加载")
            return
        }

        do {
            territories = try await territoryManager.loadAllTerritories()

            print("📥 加载到 \(territories.count) 个领地")
            for (index, territory) in territories.enumerated() {
                print("📥   领地 \(index + 1): \(territory.name ?? "未命名"), 用户ID: \(territory.userId), 点数: \(territory.path.count)")
            }

            print("📥 触发地图重绘，版本号: \(territoriesVersion) -> \(territoriesVersion + 1)")
            territoriesVersion += 1  // 触发地图重绘

            print("✅ 领地加载完成")
        } catch {
            print("❌ 加载领地失败: \(error.localizedDescription)")
        }
    }

    /// 显示上传成功提示
    private func showUploadSuccess(_ message: String) {
        uploadResultMessage = message
        withAnimation {
            showUploadResult = true
            showValidationBanner = false
        }

        // 3 秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showUploadResult = false
                uploadResultMessage = nil
            }
        }
    }

    /// 显示上传错误提示
    private func showUploadError(_ message: String) {
        uploadResultMessage = message
        withAnimation {
            showUploadResult = true
        }

        // 3 秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showUploadResult = false
                uploadResultMessage = nil
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
}
