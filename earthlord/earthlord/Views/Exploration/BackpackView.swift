//
//  BackpackView.swift
//  earthlord
//
//  背包管理页面
//  显示玩家拥有的物品，支持搜索、筛选、使用和存储
//

import SwiftUI

struct BackpackView: View {

    // MARK: - 状态

    /// 探索管理器
    @ObservedObject private var explorationManager = ExplorationManager.shared

    /// 搜索关键词
    @State private var searchText = ""

    /// 当前选中的分类筛选
    @State private var selectedCategory: ItemCategory? = nil

    /// 背包最大容量
    private let maxCapacity = 100

    // MARK: - 计算属性

    /// 当前已使用容量（按物品数量计算）
    private var currentCapacity: Int {
        explorationManager.inventoryItems.reduce(0) { $0 + $1.quantity }
    }

    /// 容量使用百分比
    private var capacityPercentage: Double {
        Double(currentCapacity) / Double(maxCapacity)
    }

    /// 容量进度条颜色
    private var capacityColor: Color {
        if capacityPercentage < 0.7 {
            return .green
        } else if capacityPercentage < 0.9 {
            return .yellow
        } else {
            return .red
        }
    }

    /// 筛选后的物品列表
    private var filteredItems: [InventoryItem] {
        var result = explorationManager.inventoryItems

        // 按分类筛选
        if let category = selectedCategory {
            result = MockExplorationData.filterItems(items: result, by: category)
        }

        // 按搜索关键词筛选
        if !searchText.isEmpty {
            result = result.filter { item in
                guard let definition = MockExplorationData.getItemDefinition(by: item.definitionId) else {
                    return false
                }
                return definition.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    // MARK: - 视图主体

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 容量状态卡
                capacityCard
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // 搜索框
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // 分类筛选按钮
                categoryFilterBar
                    .padding(.top, 12)

                // 物品列表
                if filteredItems.isEmpty {
                    emptyState
                } else {
                    itemList
                }
            }
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 容量状态卡

    /// 背包容量显示卡片
    private var capacityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 容量文字
            HStack {
                Text("背包容量：\(currentCapacity) / \(maxCapacity)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 超过 90% 显示警告
                if capacityPercentage > 0.9 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                        Text("背包快满了！")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.red)
                }
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    // 进度
                    RoundedRectangle(cornerRadius: 4)
                        .fill(capacityColor)
                        .frame(width: geometry.size.width * capacityPercentage)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 搜索框

    /// 搜索输入框
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textSecondary)

            TextField("搜索物品...", text: $searchText)
                .foregroundColor(ApocalypseTheme.textPrimary)

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    // MARK: - 分类筛选栏

    /// 分类筛选按钮栏（横向滚动）
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部" 按钮
                categoryButton(category: nil, label: "全部", icon: "square.grid.2x2")

                // 各分类按钮
                categoryButton(category: .food, label: "食物", icon: "fork.knife")
                categoryButton(category: .water, label: "水", icon: "drop.fill")
                categoryButton(category: .material, label: "材料", icon: "hammer.fill")
                categoryButton(category: .tool, label: "工具", icon: "wrench.fill")
                categoryButton(category: .medical, label: "医疗", icon: "cross.case.fill")
                categoryButton(category: .weapon, label: "武器", icon: "scope")
                categoryButton(category: .clothing, label: "服装", icon: "tshirt.fill")
                categoryButton(category: .misc, label: "杂物", icon: "shippingbox.fill")
            }
            .padding(.horizontal, 16)
        }
    }

    /// 单个分类按钮
    private func categoryButton(category: ItemCategory?, label: String, icon: String) -> some View {
        let isSelected = selectedCategory == category

        return Button(action: {
            selectedCategory = category
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            .cornerRadius(20)
        }
    }

    // MARK: - 物品列表

    /// 物品列表（滚动）
    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredItems) { item in
                    itemRow(item: item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    /// 单个物品行
    private func itemRow(item: InventoryItem) -> some View {
        guard let definition = MockExplorationData.getItemDefinition(by: item.definitionId) else {
            return AnyView(EmptyView())
        }

        return AnyView(
            HStack(spacing: 12) {
                // 左侧圆形图标
                ZStack {
                    Circle()
                        .fill(categoryColor(definition.category).opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: categoryIcon(definition.category))
                        .font(.system(size: 20))
                        .foregroundColor(categoryColor(definition.category))
                }

                // 中间信息
                VStack(alignment: .leading, spacing: 4) {
                    // 物品名称
                    Text(definition.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 数量、重量、品质
                    HStack(spacing: 8) {
                        // 数量
                        Text("x\(item.quantity)")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        // 重量
                        Text("(\(String(format: "%.1f", definition.weight * Double(item.quantity)))kg)")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        // 品质（如果有）
                        if let quality = item.quality {
                            Text(quality.rawValue)
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(qualityColor(quality))
                                .cornerRadius(4)
                        }

                        // 稀有度标签
                        rarityTag(rarity: definition.rarity)
                    }
                }

                Spacer()

                // 右侧操作按钮
                VStack(spacing: 8) {
                    // "使用" 按钮
                    Button(action: {
                        Task {
                            do {
                                try await explorationManager.useItem(inventoryItemId: item.id)
                                print("✅ 使用物品: \(definition.name)")
                            } catch {
                                print("❌ 使用失败: \(error.localizedDescription)")
                            }
                        }
                    }) {
                        Text("使用")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(6)
                    }

                    // "丢弃" 按钮
                    Button(action: {
                        Task {
                            do {
                                try await explorationManager.discardItem(inventoryItemId: item.id, quantity: 1)
                                print("✅ 丢弃物品: \(definition.name)")
                            } catch {
                                print("❌ 丢弃失败: \(error.localizedDescription)")
                            }
                        }
                    }) {
                        Text("丢弃")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(6)
                    }
                }
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        )
    }

    // MARK: - 空状态

    /// 空状态视图
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tray.fill")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("背包空空如也")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            if !searchText.isEmpty || selectedCategory != nil {
                Text("试试调整筛选条件")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 辅助方法

    /// 获取分类对应的颜色
    private func categoryColor(_ category: ItemCategory) -> Color {
        switch category {
        case .water:
            return .blue
        case .food:
            return .green
        case .medical:
            return .red
        case .material:
            return .brown
        case .tool:
            return .orange
        case .weapon:
            return .purple
        case .clothing:
            return .cyan
        case .misc:
            return .gray
        }
    }

    /// 获取分类对应的图标
    private func categoryIcon(_ category: ItemCategory) -> String {
        switch category {
        case .water:
            return "drop.fill"
        case .food:
            return "fork.knife"
        case .medical:
            return "cross.case.fill"
        case .material:
            return "hammer.fill"
        case .tool:
            return "wrench.fill"
        case .weapon:
            return "scope"
        case .clothing:
            return "tshirt.fill"
        case .misc:
            return "shippingbox.fill"
        }
    }

    /// 稀有度标签
    private func rarityTag(rarity: ItemRarity) -> some View {
        Text(rarity.rawValue)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(rarityColor(rarity))
            .cornerRadius(4)
    }

    /// 获取稀有度对应的颜色
    private func rarityColor(_ rarity: ItemRarity) -> Color {
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

    /// 获取品质对应的颜色
    private func qualityColor(_ quality: ItemQuality) -> Color {
        switch quality {
        case .pristine:
            return .green
        case .good:
            return .blue
        case .worn:
            return .yellow
        case .damaged:
            return .orange
        case .broken:
            return .red
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationView {
        BackpackView()
    }
}
