//
//  CreateTradeOfferView.swift
//  earthlord
//
//  发布交易挂单页面
//  从背包选择物品发布"我用 A 换 B"的挂单
//

import SwiftUI

struct CreateTradeOfferView: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var explorationManager = ExplorationManager.shared
    @ObservedObject private var tradeManager = TradeManager.shared

    // 出售物品
    @State private var offeringSelections: [ItemSelection] = []
    // 求购物品
    @State private var requestingSelections: [ItemSelection] = []
    // 留言
    @State private var message: String = ""
    // 过期时间（小时）
    @State private var expirationHours: Int = 24
    // 选择器状态
    @State private var showOfferingPicker = false
    @State private var showRequestingPicker = false
    // 提交状态
    @State private var isSubmitting = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var didSucceed = false

    /// 内部物品选择模型
    struct ItemSelection: Identifiable {
        let id = UUID()
        let itemId: String
        var quantity: Int
        let maxQuantity: Int

        var displayName: String {
            MockExplorationData.getItemDefinition(by: itemId)?.name ?? itemId
        }
    }

    /// 背包中可选的物品（去重汇总）
    private var availableItems: [(id: String, name: String, quantity: Int)] {
        var map: [String: Int] = [:]
        for item in explorationManager.inventoryItems {
            map[item.definitionId, default: 0] += item.quantity
        }
        return map.compactMap { key, value in
            guard let def = MockExplorationData.getItemDefinition(by: key) else { return nil }
            return (id: key, name: def.name, quantity: value)
        }
        .sorted { $0.name < $1.name }
    }

    private var canSubmit: Bool {
        !offeringSelections.isEmpty && !requestingSelections.isEmpty && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 出售物品区域
                        itemSection(
                            title: "我出售",
                            icon: "arrow.up.circle.fill",
                            color: ApocalypseTheme.primary,
                            selections: $offeringSelections,
                            onAdd: { showOfferingPicker = true }
                        )

                        // 分隔箭头
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(ApocalypseTheme.primary)

                        // 求购物品区域
                        itemSection(
                            title: "我求购",
                            icon: "arrow.down.circle.fill",
                            color: ApocalypseTheme.info,
                            selections: $requestingSelections,
                            onAdd: { showRequestingPicker = true }
                        )

                        // 留言
                        VStack(alignment: .leading, spacing: 8) {
                            Text("留言（可选）")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            TextField("给其他玩家的留言...", text: $message)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .padding(12)
                                .background(ApocalypseTheme.cardBackground)
                                .cornerRadius(10)
                        }

                        // 过期时间
                        VStack(alignment: .leading, spacing: 8) {
                            Text("有效期")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach([1, 6, 12, 24, 48, 72], id: \.self) { hours in
                                        Button {
                                            expirationHours = hours
                                        } label: {
                                            Text("\(hours)小时")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(expirationHours == hours ? .white : ApocalypseTheme.textSecondary)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(expirationHours == hours ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                        }

                        // 发布按钮
                        Button {
                            submitOffer()
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                }
                                Text("发布挂单")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canSubmit ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                            .cornerRadius(12)
                        }
                        .disabled(!canSubmit)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("发布挂单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .sheet(isPresented: $showOfferingPicker) {
                TradeItemPickerView(
                    mode: .fromInventory,
                    existingSelections: offeringSelections.map(\.itemId),
                    onSelect: { itemId, qty in
                        let maxQty = availableItems.first(where: { $0.id == itemId })?.quantity ?? qty
                        offeringSelections.append(ItemSelection(itemId: itemId, quantity: qty, maxQuantity: maxQty))
                    }
                )
            }
            .sheet(isPresented: $showRequestingPicker) {
                TradeItemPickerView(
                    mode: .anyItem,
                    existingSelections: requestingSelections.map(\.itemId),
                    onSelect: { itemId, qty in
                        requestingSelections.append(ItemSelection(itemId: itemId, quantity: qty, maxQuantity: 999))
                    }
                )
            }
            .alert("提示", isPresented: $showAlert) {
                Button("确定") {
                    if didSucceed { dismiss() }
                }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    // MARK: - 物品区域

    private func itemSection(
        title: String,
        icon: String,
        color: Color,
        selections: Binding<[ItemSelection]>,
        onAdd: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 22))
                        .foregroundColor(color)
                }
            }

            if selections.wrappedValue.isEmpty {
                Text("点击 + 添加物品")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(ApocalypseTheme.cardBackground.opacity(0.5))
                    .cornerRadius(8)
            } else {
                ForEach(selections.wrappedValue) { selection in
                    HStack {
                        Text(selection.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Spacer()

                        // 数量调节
                        HStack(spacing: 8) {
                            Button {
                                if let idx = selections.wrappedValue.firstIndex(where: { $0.id == selection.id }),
                                   selections.wrappedValue[idx].quantity > 1 {
                                    selections.wrappedValue[idx].quantity -= 1
                                }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                            }

                            Text("x\(selection.quantity)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .frame(minWidth: 30)

                            Button {
                                if let idx = selections.wrappedValue.firstIndex(where: { $0.id == selection.id }),
                                   selections.wrappedValue[idx].quantity < selection.maxQuantity {
                                    selections.wrappedValue[idx].quantity += 1
                                }
                            } label: {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                            }
                        }

                        // 删除
                        Button {
                            selections.wrappedValue.removeAll { $0.id == selection.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(ApocalypseTheme.danger.opacity(0.7))
                        }
                    }
                    .padding(10)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - 提交

    private func submitOffer() {
        isSubmitting = true

        let offering = offeringSelections.map { TradeItem(itemId: $0.itemId, quantity: $0.quantity) }
        let requesting = requestingSelections.map { TradeItem(itemId: $0.itemId, quantity: $0.quantity) }

        Task {
            do {
                try await tradeManager.createTradeOffer(
                    offeringItems: offering,
                    requestingItems: requesting,
                    expirationHours: expirationHours,
                    message: message.isEmpty ? nil : message
                )
                alertMessage = "挂单发布成功！物品已从背包扣除"
                didSucceed = true
                showAlert = true
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
            isSubmitting = false
        }
    }
}
