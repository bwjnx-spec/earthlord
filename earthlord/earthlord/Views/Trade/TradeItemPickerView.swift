//
//  TradeItemPickerView.swift
//  earthlord
//
//  增强版物品选择器
//  支持搜索、分类筛选、数量选择，用于交易发布页面
//

import SwiftUI

struct TradeItemPickerView: View {

    // MARK: - 选择器模式

    enum PickerMode {
        case fromInventory   // 从背包选择（最大=拥有量）
        case anyItem         // 任意物品（最大=999）
    }

    // MARK: - 属性

    let mode: PickerMode
    let existingSelections: [String]
    let onSelect: (String, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var explorationManager = ExplorationManager.shared

    // MARK: - 状态

    @State private var searchText = ""
    @State private var selectedCategory: ItemCategory? = nil
    @State private var selectedItem: PickerItem? = nil
    @State private var quantity: Int = 1

    // MARK: - 内部模型

    struct PickerItem: Identifiable {
        let id: String
        let name: String
        let category: ItemCategory
        let rarity: ItemRarity
        let maxQuantity: Int
        let isDisabled: Bool
    }

    // MARK: - 计算属性

    private var pickerItems: [PickerItem] {
        switch mode {
        case .fromInventory:
            var map: [String: Int] = [:]
            for item in explorationManager.inventoryItems {
                map[item.definitionId, default: 0] += item.quantity
            }
            return map.compactMap { key, value in
                guard let def = MockExplorationData.getItemDefinition(by: key) else { return nil }
                return PickerItem(
                    id: key,
                    name: def.name,
                    category: def.category,
                    rarity: def.rarity,
                    maxQuantity: value,
                    isDisabled: existingSelections.contains(key)
                )
            }
            .sorted { $0.name < $1.name }

        case .anyItem:
            return MockExplorationData.itemDefinitions.map { def in
                PickerItem(
                    id: def.id,
                    name: def.name,
                    category: def.category,
                    rarity: def.rarity,
                    maxQuantity: 999,
                    isDisabled: existingSelections.contains(def.id)
                )
            }
            .sorted { $0.name < $1.name }
        }
    }

    private var filteredItems: [PickerItem] {
        var result = pickerItems

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    private var groupedItems: [(category: ItemCategory, items: [PickerItem])] {
        let grouped = Dictionary(grouping: filteredItems) { $0.category }
        return ItemCategory.allCases.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (category: cat, items: items)
        }
    }

    // MARK: - 视图主体

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if selectedItem != nil {
                    quantityView
                } else {
                    browseView
                }
            }
            .navigationTitle(selectedItem != nil ? "选择数量" : "选择物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectedItem != nil {
                        Button {
                            selectedItem = nil
                            quantity = 1
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("返回")
                            }
                            .foregroundColor(ApocalypseTheme.primary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // MARK: - 浏览视图

    private var browseView: some View {
        VStack(spacing: 0) {
            // 搜索栏
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // 分类筛选
            categoryFilterBar
                .padding(.top, 10)

            // 物品列表
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text("没有找到物品")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(groupedItems, id: \.category) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                // 分类标题
                                HStack(spacing: 6) {
                                    Image(systemName: categoryIcon(group.category))
                                        .font(.system(size: 13))
                                        .foregroundColor(categoryColor(group.category))
                                    Text(group.category.rawValue)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }
                                .padding(.horizontal, 16)

                                // 物品行
                                ForEach(group.items) { item in
                                    itemRow(item: item)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textSecondary)

            TextField("搜索物品...", text: $searchText)
                .foregroundColor(ApocalypseTheme.textPrimary)

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
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

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryChip(category: nil, label: "全部", icon: "square.grid.2x2")
                categoryChip(category: .food, label: "食物", icon: "fork.knife")
                categoryChip(category: .water, label: "水", icon: "drop.fill")
                categoryChip(category: .material, label: "材料", icon: "hammer.fill")
                categoryChip(category: .tool, label: "工具", icon: "wrench.fill")
                categoryChip(category: .medical, label: "医疗", icon: "cross.case.fill")
                categoryChip(category: .weapon, label: "武器", icon: "scope")
                categoryChip(category: .clothing, label: "服装", icon: "tshirt.fill")
                categoryChip(category: .misc, label: "杂物", icon: "shippingbox.fill")
            }
            .padding(.horizontal, 16)
        }
    }

    private func categoryChip(category: ItemCategory?, label: String, icon: String) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            .cornerRadius(18)
        }
    }

    // MARK: - 物品行

    private func itemRow(item: PickerItem) -> some View {
        Button {
            if !item.isDisabled {
                selectedItem = item
                quantity = 1
            }
        } label: {
            HStack(spacing: 12) {
                // 分类图标圆圈
                ZStack {
                    Circle()
                        .fill(categoryColor(item.category).opacity(0.2))
                        .frame(width: 42, height: 42)
                    Image(systemName: categoryIcon(item.category))
                        .font(.system(size: 17))
                        .foregroundColor(categoryColor(item.category))
                }

                // 物品信息
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(item.isDisabled ? ApocalypseTheme.textMuted : ApocalypseTheme.textPrimary)

                    if mode == .fromInventory {
                        Text("拥有 x\(item.maxQuantity)")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()

                if item.isDisabled {
                    Text("已选")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(6)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
            .opacity(item.isDisabled ? 0.5 : 1.0)
        }
        .disabled(item.isDisabled)
    }

    // MARK: - 数量选择视图

    private var quantityView: some View {
        VStack(spacing: 24) {
            Spacer()

            if let item = selectedItem {
                // 物品信息
                ZStack {
                    Circle()
                        .fill(categoryColor(item.category).opacity(0.2))
                        .frame(width: 80, height: 80)
                    Image(systemName: categoryIcon(item.category))
                        .font(.system(size: 34))
                        .foregroundColor(categoryColor(item.category))
                }

                Text(item.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if mode == .fromInventory {
                    Text("拥有 x\(item.maxQuantity)")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 数量选择器
                HStack(spacing: 24) {
                    Button {
                        if quantity > 1 { quantity -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(quantity > 1 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    }
                    .disabled(quantity <= 1)

                    Text("\(quantity)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(minWidth: 60)

                    Button {
                        if quantity < item.maxQuantity { quantity += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(quantity < item.maxQuantity ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    }
                    .disabled(quantity >= item.maxQuantity)
                }
                .padding(.vertical, 12)

                // 快捷数量按钮
                if item.maxQuantity > 1 {
                    HStack(spacing: 12) {
                        quickQuantityButton(value: 1, max: item.maxQuantity)
                        if item.maxQuantity >= 5 {
                            quickQuantityButton(value: 5, max: item.maxQuantity)
                        }
                        if item.maxQuantity >= 10 {
                            quickQuantityButton(value: 10, max: item.maxQuantity)
                        }
                        quickQuantityButton(value: item.maxQuantity, max: item.maxQuantity, label: "全部")
                    }
                }
            }

            Spacer()

            // 确认按钮
            Button {
                if let item = selectedItem {
                    onSelect(item.id, quantity)
                    dismiss()
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("确认添加")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(ApocalypseTheme.primary)
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func quickQuantityButton(value: Int, max: Int, label: String? = nil) -> some View {
        let actualValue = min(value, max)
        let isSelected = quantity == actualValue
        return Button {
            quantity = actualValue
        } label: {
            Text(label ?? "x\(actualValue)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                .cornerRadius(8)
        }
    }

    // MARK: - 辅助方法

    private func categoryColor(_ category: ItemCategory) -> Color {
        switch category {
        case .water: return .blue
        case .food: return .green
        case .medical: return .red
        case .material: return .brown
        case .tool: return .orange
        case .weapon: return .purple
        case .clothing: return .cyan
        case .misc: return .gray
        }
    }

    private func categoryIcon(_ category: ItemCategory) -> String {
        switch category {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.case.fill"
        case .material: return "hammer.fill"
        case .tool: return "wrench.fill"
        case .weapon: return "scope"
        case .clothing: return "tshirt.fill"
        case .misc: return "shippingbox.fill"
        }
    }
}
