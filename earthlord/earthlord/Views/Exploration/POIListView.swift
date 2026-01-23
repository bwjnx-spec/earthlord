//
//  POIListView.swift
//  earthlord
//
//  显示附近兴趣点的列表页面
//  包含状态栏、搜索按钮、筛选工具栏和 POI 列表
//

import SwiftUI
import CoreLocation

struct POIListView: View {

    // MARK: - 状态

    /// 探索管理器
    @ObservedObject private var explorationManager = ExplorationManager.shared

    /// 是否正在搜索中
    @State private var isSearching = false

    /// 当前选中的筛选分类（nil 表示全部）
    @State private var selectedFilter: POIType? = nil

    /// 导航到 POI 详情
    @State private var selectedPOI: POI?

    /// 搜索按钮按下状态（用于缩放动画）
    @State private var isSearchButtonPressed = false

    /// POI 列表是否已显示（用于淡入动画）
    @State private var poisAppeared: Set<UUID> = []

    // MARK: - 计算属性

    /// 当前 GPS 坐标
    private var currentCoordinate: (latitude: Double, longitude: Double) {
        if let location = explorationManager.currentLocation {
            return (location.latitude, location.longitude)
        }
        return (0.0, 0.0)
    }

    /// 位置是否已授权
    private var isLocationAuthorized: Bool {
        explorationManager.currentLocation != nil
    }

    /// 筛选后的 POI 列表
    private var filteredPOIs: [POI] {
        if let filter = selectedFilter {
            return explorationManager.nearbyPOIs.filter { $0.type == filter }
        }
        return explorationManager.nearbyPOIs
    }

    /// 已发现的 POI 数量
    private var discoveredCount: Int {
        explorationManager.nearbyPOIs.filter { $0.status != .undiscovered }.count
    }

    // MARK: - 视图主体

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 状态栏
                statusBar

                // 搜索按钮
                searchButton
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                // 筛选工具栏
                filterToolbar

                // POI 列表
                poiList
            }
        }
        .navigationTitle("附近地点")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedPOI) { poi in
            POIDetailView(poi: poi)
        }
        .onAppear {
            Task {
                await explorationManager.checkNearbyPOIs()
            }
        }
    }

    // MARK: - 状态栏

    /// 顶部状态栏，显示 GPS 坐标和发现数量
    private var statusBar: some View {
        HStack {
            // GPS 坐标
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isLocationAuthorized ? ApocalypseTheme.success : ApocalypseTheme.danger)

                Text(String(format: "%.4f, %.4f", currentCoordinate.latitude, currentCoordinate.longitude))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 发现数量
            Text("附近发现 \(discoveredCount) 个地点")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 搜索按钮

    /// 大搜索按钮
    private var searchButton: some View {
        Button(action: performSearch) {
            HStack(spacing: 12) {
                if isSearching {
                    // 加载动画
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)

                    Text("搜索中...")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    // 正常状态
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text("搜索附近POI")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: isSearching
                        ? [ApocalypseTheme.textMuted, ApocalypseTheme.textMuted]
                        : [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .scaleEffect(isSearchButtonPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSearchButtonPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isSearchButtonPressed = true }
                .onEnded { _ in isSearchButtonPressed = false }
        )
        .disabled(isSearching)
    }

    // MARK: - 筛选工具栏

    /// 横向滚动的分类筛选按钮
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // "全部"按钮
                FilterChip(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedFilter == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = nil
                    }
                }

                // 各分类按钮
                FilterChip(
                    title: "医院",
                    icon: "cross.case.fill",
                    color: .red,
                    isSelected: selectedFilter == .hospital
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = .hospital
                    }
                }

                FilterChip(
                    title: "超市",
                    icon: "cart.fill",
                    color: .green,
                    isSelected: selectedFilter == .supermarket
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = .supermarket
                    }
                }

                FilterChip(
                    title: "工厂",
                    icon: "building.2.fill",
                    color: .gray,
                    isSelected: selectedFilter == .factory
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = .factory
                    }
                }

                FilterChip(
                    title: "药店",
                    icon: "pills.fill",
                    color: .purple,
                    isSelected: selectedFilter == .pharmacy
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = .pharmacy
                    }
                }

                FilterChip(
                    title: "加油站",
                    icon: "fuelpump.fill",
                    color: .orange,
                    isSelected: selectedFilter == .gasStation
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = .gasStation
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    // MARK: - POI 列表

    /// POI 列表视图
    private var poiList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredPOIs.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    ForEach(filteredPOIs) { poi in
                        POICard(poi: poi)
                            .opacity(poisAppeared.contains(poi.id) ? 1 : 0)
                            .offset(y: poisAppeared.contains(poi.id) ? 0 : 20)
                            .onAppear {
                                // 淡入动画
                                let index = filteredPOIs.firstIndex(where: { $0.id == poi.id }) ?? 0
                                withAnimation(.easeOut(duration: 0.3).delay(Double(index) * 0.1)) {
                                    _ = poisAppeared.insert(poi.id)
                                }
                            }
                            .onTapGesture {
                                handlePOITap(poi)
                            }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            if explorationManager.nearbyPOIs.isEmpty {
                // 没有任何POI
                Image(systemName: "map")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("附近暂无兴趣点")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("点击搜索按钮发现周围的废墟")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                // 筛选后没有结果
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("没有找到该类型的地点")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 方法

    /// 执行搜索操作
    private func performSearch() {
        isSearching = true
        // 重置淡入状态，让列表重新动画
        poisAppeared.removeAll()

        Task {
            await explorationManager.checkNearbyPOIs()

            // 延迟模拟网络请求
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒

            isSearching = false
            print("🔍 搜索完成，发现 \(explorationManager.nearbyPOIs.count) 个 POI")
        }
    }

    /// 处理 POI 点击事件
    private func handlePOITap(_ poi: POI) {
        selectedPOI = poi
    }
}

// MARK: - 筛选按钮组件

/// 筛选分类按钮
struct FilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? color
                    : ApocalypseTheme.cardBackground
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? color : ApocalypseTheme.textMuted.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - POI 卡片组件

/// 单个 POI 卡片
struct POICard: View {
    let poi: POI

    /// 根据 POI 类型返回对应的颜色
    private var typeColor: Color {
        switch poi.type {
        case .hospital:
            return .red
        case .supermarket:
            return .green
        case .factory:
            return .gray
        case .pharmacy:
            return .purple
        case .gasStation:
            return .orange
        case .warehouse:
            return .brown
        case .residence:
            return .blue
        case .policeStation:
            return .indigo
        case .fireStation:
            return .red.opacity(0.8)
        }
    }

    /// 根据 POI 类型返回对应的图标
    private var typeIcon: String {
        switch poi.type {
        case .hospital:
            return "cross.case.fill"
        case .supermarket:
            return "cart.fill"
        case .factory:
            return "building.2.fill"
        case .pharmacy:
            return "pills.fill"
        case .gasStation:
            return "fuelpump.fill"
        case .warehouse:
            return "shippingbox.fill"
        case .residence:
            return "house.fill"
        case .policeStation:
            return "shield.fill"
        case .fireStation:
            return "flame.fill"
        }
    }

    /// 根据 POI 状态返回状态文字
    private var statusText: String {
        switch poi.status {
        case .undiscovered:
            return "未发现"
        case .discovered:
            return "已发现"
        case .hasLoot:
            return "有物资"
        case .looted:
            return "已搜空"
        case .dangerous:
            return "危险"
        }
    }

    /// 根据 POI 状态返回状态颜色
    private var statusColor: Color {
        switch poi.status {
        case .undiscovered:
            return ApocalypseTheme.textMuted
        case .discovered:
            return ApocalypseTheme.info
        case .hasLoot:
            return ApocalypseTheme.success
        case .looted:
            return ApocalypseTheme.textSecondary
        case .dangerous:
            return ApocalypseTheme.danger
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // 左侧：类型图标
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: typeIcon)
                    .font(.system(size: 22))
                    .foregroundColor(typeColor)
            }

            // 中间：名称和类型
            VStack(alignment: .leading, spacing: 6) {
                // POI 名称
                Text(poi.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 类型和危险等级
                HStack(spacing: 8) {
                    Text(poi.type.rawValue)
                        .font(.system(size: 13))
                        .foregroundColor(typeColor)

                    // 危险等级指示器
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { level in
                            Circle()
                                .fill(level <= poi.dangerLevel
                                      ? ApocalypseTheme.danger
                                      : ApocalypseTheme.textMuted.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }

            Spacer()

            // 右侧：状态标签
            VStack(alignment: .trailing, spacing: 6) {
                // 发现状态
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .cornerRadius(10)

                // 物资数量（如果有物资）
                if poi.status == .hasLoot && !poi.lootItems.isEmpty {
                    Text("\(poi.lootItems.count) 种物资")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.success)
                }
            }

            // 箭头指示器
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(typeColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        POIListView()
    }
}
