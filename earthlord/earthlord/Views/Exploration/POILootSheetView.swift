//
//  POILootSheetView.swift
//  earthlord
//
//  POI 搜刮提示弹窗
//  显示 POI 信息、可获得物品预览、搜刮按钮和搜刮结果
//

import SwiftUI

/// POI 搜刮弹窗视图
struct POILootSheetView: View {

    // MARK: - Properties

    /// POI 数据
    let poi: POI

    /// 关闭弹窗回调
    let onDismiss: () -> Void

    /// 搜刮完成回调
    let onLootComplete: (ExplorationResult?) -> Void

    // MARK: - State

    /// 是否正在搜刮
    @State private var isLooting = false

    /// 搜刮结果
    @State private var lootResult: ExplorationResult?

    /// 错误消息
    @State private var errorMessage: String?

    /// 探索管理器
    @StateObject private var explorationManager = ExplorationManager.shared

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // POI 信息卡片
                    poiInfoCard

                    // 可获得物品预览
                    if !poi.availableLoot.isEmpty && lootResult == nil {
                        lootPreviewSection
                    }

                    // 搜刮结果
                    if let result = lootResult {
                        lootResultSection(result: result)
                    }

                    // 错误提示
                    if let error = errorMessage {
                        errorView(message: error)
                    }

                    // 操作按钮
                    actionButtons
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("搜刮")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        onDismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    /// POI 信息卡片
    private var poiInfoCard: some View {
        VStack(spacing: 16) {
            // 图标和名称
            HStack(spacing: 16) {
                // POI 类型图标
                ZStack {
                    Circle()
                        .fill(poiTypeColor.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: poiTypeIcon)
                        .font(.system(size: 28))
                        .foregroundColor(poiTypeColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // POI 名称
                    Text(poi.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(2)

                    // POI 类型
                    Text(poi.type.rawValue)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 距离
                    if let distance = poi.distance {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(formatDistance(distance))
                                .font(.caption)
                        }
                        .foregroundColor(distance <= lootDistanceThreshold ? ApocalypseTheme.success : ApocalypseTheme.warning)
                    }
                }

                Spacer()

                // 危险等级
                VStack(spacing: 2) {
                    Text("危险")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)

                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { level in
                            Image(systemName: level <= poi.dangerLevel ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                                .font(.caption2)
                                .foregroundColor(level <= poi.dangerLevel ? dangerLevelColor : ApocalypseTheme.textMuted)
                        }
                    }
                }
            }

            // 描述
            Text(poi.description)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    /// 可获得物品预览
    private var lootPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cube.box.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("可能获得的物资")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 物品网格
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(poi.availableLoot.prefix(6), id: \.self) { itemId in
                    if let definition = MockExplorationData.getItemDefinition(by: itemId) {
                        VStack(spacing: 4) {
                            // 物品图标（使用分类图标）
                            Image(systemName: itemCategoryIcon(definition.category))
                                .font(.title2)
                                .foregroundColor(itemRarityColor(definition.rarity))

                            // 物品名称
                            Text(definition.name)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .lineLimit(1)

                            // 稀有度
                            Text(definition.rarity.rawValue)
                                .font(.caption2)
                                .foregroundColor(itemRarityColor(definition.rarity))
                        }
                        .padding(8)
                        .background(ApocalypseTheme.background)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    /// 搜刮结果
    private func lootResultSection(result: ExplorationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(ApocalypseTheme.success)
                Text("搜刮成功！")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.success)

                Spacer()

                // 经验值
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("+\(result.experienceGained) EXP")
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                }
            }

            // 获得的物品
            if result.itemsCollected.isEmpty {
                Text("这次没有找到任何物资...")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .italic()
            } else {
                ForEach(result.itemsCollected) { item in
                    lootItemRow(item: item)
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    /// 单个物品行视图
    private func lootItemRow(item: InventoryItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 物品图标
            ZStack {
                // AI 生成标记
                if item.isAIGenerated {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                        .offset(x: 10, y: -10)
                }

                Image(systemName: itemCategoryIcon(item.displayCategory))
                    .font(.title3)
                    .foregroundColor(itemRarityColor(item.displayRarity))
            }
            .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                // 物品名称
                HStack(spacing: 4) {
                    Text(item.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(itemRarityColor(item.displayRarity))
                        .lineLimit(2)

                    // AI 生成徽章
                    if item.isAIGenerated {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }

                // 稀有度和品质
                HStack(spacing: 8) {
                    // 稀有度标签
                    Text(item.displayRarity.rawValue)
                        .font(.caption2)
                        .foregroundColor(itemRarityColor(item.displayRarity))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(itemRarityColor(item.displayRarity).opacity(0.2))
                        .cornerRadius(4)

                    // 品质
                    if let quality = item.quality {
                        Text(quality.rawValue)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                // AI 生成的背景故事
                if item.isAIGenerated, let story = item.aiStory, !story.isEmpty {
                    Text(story)
                        .font(.caption)
                        .italic()
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }

            Spacer()

            // 数量
            Text("x\(item.quantity)")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.primary)
        }
        .padding(.vertical, 6)
    }

    /// 错误视图
    private func errorView(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(ApocalypseTheme.danger)

            Text(message)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.danger)

            Spacer()
        }
        .padding()
        .background(ApocalypseTheme.danger.opacity(0.1))
        .cornerRadius(12)
    }

    /// 操作按钮
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if lootResult == nil {
                // 搜刮按钮
                Button(action: {
                    performLoot()
                }) {
                    HStack {
                        if isLooting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "hand.raised.fill")
                        }
                        Text(isLooting ? "搜刮中..." : "开始搜刮")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canLoot ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .cornerRadius(12)
                }
                .disabled(!canLoot || isLooting)
            } else {
                // 完成按钮
                Button(action: {
                    onLootComplete(lootResult)
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("收取物资")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.success)
                    .cornerRadius(12)
                }
            }

            // 提示文字
            if !canLoot && lootResult == nil {
                Text(lootBlockReason)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.warning)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Computed Properties

    /// POI 类型图标
    private var poiTypeIcon: String {
        switch poi.type {
        case .hospital: return "cross.case.fill"
        case .pharmacy: return "pills.fill"
        case .gasStation: return "fuelpump.fill"
        case .supermarket: return "cart.fill"
        case .policeStation: return "shield.fill"
        case .fireStation: return "flame.fill"
        case .factory: return "gearshape.2.fill"
        case .warehouse: return "shippingbox.fill"
        case .residence: return "house.fill"
        }
    }

    /// POI 类型颜色
    private var poiTypeColor: Color {
        switch poi.type {
        case .hospital: return .red
        case .pharmacy: return .green
        case .gasStation: return .orange
        case .supermarket: return .blue
        case .policeStation: return .indigo
        case .fireStation: return .red
        case .factory: return .gray
        case .warehouse: return .brown
        case .residence: return .teal
        }
    }

    /// 危险等级颜色
    private var dangerLevelColor: Color {
        switch poi.dangerLevel {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4: return .red
        default: return .purple
        }
    }

    /// 搜刮距离阈值（米）- 与 ExplorationManager.searchRadius 保持一致
    private let lootDistanceThreshold: Double = 100.0

    /// 是否可以搜刮
    private var canLoot: Bool {
        // 检查距离（放宽到100米，与 ExplorationManager 一致）
        if let distance = poi.distance, distance > lootDistanceThreshold {
            return false
        }
        // 检查状态
        if poi.status == .looted {
            return false
        }
        return true
    }

    /// 无法搜刮的原因
    private var lootBlockReason: String {
        if let distance = poi.distance, distance > lootDistanceThreshold {
            return "距离太远（\(formatDistance(distance))），需要走到 \(Int(lootDistanceThreshold)) 米内才能搜刮"
        }
        if poi.status == .looted {
            return "该地点已被搜刮过"
        }
        return ""
    }

    // MARK: - Helper Methods

    /// 格式化距离
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f 公里", meters / 1000)
        } else {
            return String(format: "%.0f 米", meters)
        }
    }

    /// 物品分类图标
    private func itemCategoryIcon(_ category: ItemCategory) -> String {
        switch category {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.case.fill"
        case .material: return "cube.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        case .weapon: return "scope"
        case .clothing: return "tshirt.fill"
        case .misc: return "questionmark.circle.fill"
        }
    }

    /// 物品稀有度颜色
    private func itemRarityColor(_ rarity: ItemRarity) -> Color {
        switch rarity {
        case .common: return .white
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    // MARK: - Actions

    /// 执行搜刮
    private func performLoot() {
        guard canLoot else { return }

        isLooting = true
        errorMessage = nil

        Task {
            do {
                let result = try await explorationManager.searchPOI(poiId: poi.id)
                lootResult = result
            } catch {
                errorMessage = error.localizedDescription
            }
            isLooting = false
        }
    }
}

// MARK: - Preview

#Preview {
    POILootSheetView(
        poi: MockExplorationData.mockPOIs[0],
        onDismiss: {},
        onLootComplete: { _ in }
    )
}
