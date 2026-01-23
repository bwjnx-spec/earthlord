//
//  POIDetailView.swift
//  earthlord
//
//  POI 详情页面
//  点击某个 POI 后显示的详细信息和操作按钮
//

import SwiftUI

struct POIDetailView: View {

    // MARK: - 属性

    /// POI 数据
    let poi: POI

    /// 探索管理器
    @ObservedObject private var explorationManager = ExplorationManager.shared

    /// 环境变量：关闭页面
    @Environment(\.dismiss) private var dismiss

    /// 是否显示探索结果弹窗
    @State private var showExplorationResult = false

    /// 是否正在搜寻中
    @State private var isExploring = false

    /// POI 状态（可修改）
    @State private var currentStatus: POIStatus

    /// 探索会话结果（用于显示结果弹窗）
    @State private var sessionResult: ExplorationSessionResult?

    /// 错误消息
    @State private var errorMessage: String?

    /// 是否显示错误提示
    @State private var showError = false

    // MARK: - 初始化

    init(poi: POI) {
        self.poi = poi
        self._currentStatus = State(initialValue: poi.status)
    }

    // MARK: - 计算属性

    /// 当前距离（米）
    private var currentDistance: Double {
        poi.distance ?? 0
    }

    // MARK: - 计算属性

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

    /// 危险等级文字
    private var dangerLevelText: String {
        switch poi.dangerLevel {
        case 1:
            return "安全"
        case 2:
            return "低危"
        case 3:
            return "中危"
        case 4:
            return "高危"
        case 5:
            return "极危"
        default:
            return "未知"
        }
    }

    /// 危险等级颜色
    private var dangerLevelColor: Color {
        switch poi.dangerLevel {
        case 1:
            return ApocalypseTheme.success
        case 2:
            return .green.opacity(0.7)
        case 3:
            return ApocalypseTheme.warning
        case 4:
            return .orange
        case 5:
            return ApocalypseTheme.danger
        default:
            return ApocalypseTheme.textMuted
        }
    }

    /// 物资状态文字
    private var lootStatusText: String {
        switch currentStatus {
        case .hasLoot:
            return "有物资"
        case .looted:
            return "已清空"
        case .undiscovered:
            return "未探索"
        case .discovered:
            return "待搜索"
        case .dangerous:
            return "危险区域"
        }
    }

    /// 物资状态颜色
    private var lootStatusColor: Color {
        switch currentStatus {
        case .hasLoot:
            return ApocalypseTheme.success
        case .looted:
            return ApocalypseTheme.textMuted
        case .undiscovered:
            return ApocalypseTheme.info
        case .discovered:
            return ApocalypseTheme.warning
        case .dangerous:
            return ApocalypseTheme.danger
        }
    }

    /// 是否可以搜寻
    private var canExplore: Bool {
        return currentStatus != .looted && !isExploring
    }

    // MARK: - 视图主体

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶部大图区域
                    headerSection

                    // 信息区域
                    infoSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // 描述区域
                    descriptionSection
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // 可获得物资（如果有）
                    if currentStatus == .hasLoot && !poi.lootItems.isEmpty {
                        lootPreviewSection
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }

                    // 操作按钮区域
                    actionSection
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle(poi.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExplorationResult) {
            if let result = sessionResult {
                ExplorationResultView(sessionResult: result)
            }
        }
        .alert("搜寻失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    // MARK: - 顶部大图区域

    /// 顶部渐变背景和图标
    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // 渐变背景
            LinearGradient(
                colors: [
                    typeColor,
                    typeColor.opacity(0.6),
                    ApocalypseTheme.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)

            // 大图标
            VStack(spacing: 0) {
                Spacer()

                Image(systemName: typeIcon)
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                Spacer()
                    .frame(height: 60)
            }
            .frame(height: 280)

            // 底部半透明遮罩
            VStack(spacing: 4) {
                Text(poi.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text(poi.type.rawValue)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - 信息区域

    /// 信息卡片区域
    private var infoSection: some View {
        VStack(spacing: 12) {
            // 第一行：距离和物资状态
            HStack(spacing: 12) {
                // 距离
                InfoCard(
                    icon: "location.fill",
                    title: "距离",
                    value: currentDistance > 0 ? "\(Int(currentDistance))米" : "未知",
                    color: ApocalypseTheme.info
                )

                // 物资状态
                InfoCard(
                    icon: "shippingbox.fill",
                    title: "物资状态",
                    value: lootStatusText,
                    color: lootStatusColor
                )
            }

            // 第二行：危险等级和来源
            HStack(spacing: 12) {
                // 危险等级
                InfoCard(
                    icon: "exclamationmark.triangle.fill",
                    title: "危险等级",
                    value: dangerLevelText,
                    color: dangerLevelColor
                )

                // 来源
                InfoCard(
                    icon: "map.fill",
                    title: "来源",
                    value: poi.discoveredAt != nil ? "手动发现" : "地图数据",
                    color: ApocalypseTheme.textSecondary
                )
            }
        }
    }

    // MARK: - 描述区域

    /// POI 描述
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("地点描述")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(poi.description)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 可获得物资预览

    /// 物资预览区域
    private var lootPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("可能获得的物资")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text("\(poi.lootItems.count) 种")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.success)
            }

            // 物资列表
            FlowLayout(spacing: 8) {
                ForEach(poi.lootItems, id: \.self) { itemId in
                    if let definition = MockExplorationData.getItemDefinition(by: itemId) {
                        LootItemChip(name: definition.name, rarity: definition.rarity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 操作按钮区域

    /// 操作按钮
    private var actionSection: some View {
        VStack(spacing: 12) {
            // 主按钮：搜寻此 POI
            Button(action: startExploration) {
                HStack(spacing: 10) {
                    if isExploring {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)

                        Text("搜寻中...")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)

                        Text("搜寻此POI")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: canExplore
                            ? [ApocalypseTheme.primary, ApocalypseTheme.primaryDark]
                            : [ApocalypseTheme.textMuted, ApocalypseTheme.textMuted],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(!canExplore)

            // 如果已搜空，显示提示
            if currentStatus == .looted {
                Text("此地点已被搜空，无法再次搜寻")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 两个小按钮并排
            HStack(spacing: 12) {
                // 标记已发现
                Button(action: markAsDiscovered) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 14))

                        Text("标记已发现")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.info)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(ApocalypseTheme.info.opacity(0.15))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ApocalypseTheme.info.opacity(0.3), lineWidth: 1)
                    )
                }

                // 标记无物资
                Button(action: markAsLooted) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))

                        Text("标记无物资")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - 方法

    /// 开始搜寻
    private func startExploration() {
        guard canExplore else { return }

        isExploring = true
        print("🔍 开始搜寻: \(poi.name)")

        Task {
            // 模拟搜寻延迟
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 秒

            // 生成假的探索会话结果
            let mockItems = poi.lootItems.prefix(3).compactMap { itemId -> InventoryItem? in
                guard MockExplorationData.getItemDefinition(by: itemId) != nil else { return nil }
                return InventoryItem(
                    id: UUID(),
                    definitionId: itemId,
                    quantity: Int.random(in: 1...5),
                    quality: [.pristine, .good, .worn].randomElement(),
                    obtainedAt: Date(),
                    obtainedFrom: poi.name
                )
            }

            let result = ExplorationSessionResult(
                id: UUID().uuidString,
                startTime: Date().addingTimeInterval(-1800), // 30 分钟前
                endTime: Date(),
                walkDistance: Double.random(in: 500...2000),
                totalWalkDistance: Double.random(in: 10000...20000),
                walkDistanceRank: Int.random(in: 30...100),
                exploredArea: Double.random(in: 10000...50000),
                totalExploredArea: Double.random(in: 200000...500000),
                exploredAreaRank: Int.random(in: 40...120),
                itemsCollected: mockItems,
                experienceGained: Int.random(in: 50...200)
            )

            isExploring = false
            sessionResult = result

            withAnimation {
                currentStatus = .looted
            }

            showExplorationResult = true
            print("✅ 搜寻完成: \(poi.name)，获得 \(result.itemsCollected.count) 个物品")
        }
    }

    /// 标记为已发现
    private func markAsDiscovered() {
        Task {
            await explorationManager.manuallyMarkDiscovered(poiId: poi.id)

            withAnimation {
                currentStatus = .discovered
            }

            print("👁️ 已标记为已发现: \(poi.name)")
        }
    }

    /// 标记为无物资
    private func markAsLooted() {
        Task {
            await explorationManager.markPOIAsNoLoot(poiId: poi.id)

            withAnimation {
                currentStatus = .looted
            }

            print("❌ 已标记为无物资: \(poi.name)")
        }
    }
}

// MARK: - 信息卡片组件

/// 单个信息展示卡片
struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            // 标题
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 值
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - 物资标签组件

/// 物资小标签
struct LootItemChip: View {
    let name: String
    let rarity: ItemRarity

    /// 稀有度对应的颜色
    private var rarityColor: Color {
        switch rarity {
        case .common:
            return .gray
        case .uncommon:
            return .green
        case .rare:
            return .blue
        case .epic:
            return .purple
        case .legendary:
            return .orange
        }
    }

    var body: some View {
        Text(name)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(rarityColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(rarityColor.opacity(0.15))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(rarityColor.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - 流式布局组件

/// 自动换行的流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint], sizes: [CGSize]) {
        let maxWidth = proposal.width ?? .infinity

        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            if currentX + size.width > maxWidth && currentX > 0 {
                // 换行
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        totalHeight = currentY + lineHeight

        return (CGSize(width: totalWidth, height: totalHeight), positions, sizes)
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        POIDetailView(poi: MockExplorationData.mockPOIs[0])
    }
}
