//
//  TradeOfferDetailView.swift
//  earthlord
//
//  交易挂单详情页
//  显示出售/求购物品、库存检查、接受交易确认
//

import SwiftUI

struct TradeOfferDetailView: View {

    // MARK: - 属性

    let offer: TradeOffer

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var tradeManager = TradeManager.shared
    @ObservedObject private var explorationManager = ExplorationManager.shared

    // MARK: - 状态

    @State private var showAcceptConfirmation = false
    @State private var isAccepting = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var didSucceed = false

    // MARK: - 库存检查

    struct InventoryCheckItem: Identifiable {
        let id: String
        let itemId: String
        let displayName: String
        let category: ItemCategory
        let required: Int
        let owned: Int
        var sufficient: Bool { owned >= required }
    }

    private var inventoryCheck: [InventoryCheckItem] {
        var resources: [String: Int] = [:]
        for item in explorationManager.inventoryItems {
            resources[item.definitionId, default: 0] += item.quantity
        }

        return offer.requestingItems.map { tradeItem in
            let owned = resources[tradeItem.itemId] ?? 0
            let def = MockExplorationData.getItemDefinition(by: tradeItem.itemId)
            return InventoryCheckItem(
                id: tradeItem.itemId,
                itemId: tradeItem.itemId,
                displayName: def?.name ?? tradeItem.itemId,
                category: def?.category ?? .misc,
                required: tradeItem.quantity,
                owned: owned
            )
        }
    }

    private var canAccept: Bool {
        offer.isAcceptable && inventoryCheck.allSatisfy(\.sufficient)
    }

    // MARK: - 视图主体

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // 状态头部
                    headerCard

                    // 出售物品
                    offeringSection

                    // 交换箭头
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(ApocalypseTheme.primary)

                    // 求购物品 + 库存检查
                    requestingSection

                    // 卖家留言
                    if let message = offer.message, !message.isEmpty {
                        messageCard(message: message)
                    }

                    // 接受交易按钮
                    if offer.isAcceptable {
                        acceptButton
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("交易详情")
        .navigationBarTitleDisplayMode(.inline)
        .alert("确认交易", isPresented: $showAcceptConfirmation) {
            Button("取消", role: .cancel) {}
            Button("确认交易", role: .destructive) { acceptOffer() }
        } message: {
            Text(acceptConfirmMessage)
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定") {
                if didSucceed { dismiss() }
            }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    // MARK: - 状态头部

    private var headerCard: some View {
        VStack(spacing: 10) {
            HStack {
                statusBadge(status: offer.status)

                Spacer()

                Text(offer.createdAt, style: .date)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            if offer.status == .active {
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                    Text("剩余时间: \(offer.formattedRemainingTime)")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                }
                .foregroundColor(offer.isExpired ? ApocalypseTheme.danger : ApocalypseTheme.textSecondary)
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 出售物品区域

    private var offeringSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("出售物品")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            ForEach(offer.offeringItems) { item in
                itemDetailRow(item: item)
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 求购物品区域（含库存检查）

    private var requestingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(ApocalypseTheme.info)
                Text("求购物品")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
                if offer.isAcceptable {
                    Text("库存检查")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            ForEach(inventoryCheck) { check in
                HStack(spacing: 12) {
                    // 分类图标
                    ZStack {
                        Circle()
                            .fill(categoryColor(check.category).opacity(0.2))
                            .frame(width: 38, height: 38)
                        Image(systemName: categoryIcon(check.category))
                            .font(.system(size: 15))
                            .foregroundColor(categoryColor(check.category))
                    }

                    // 物品名称和数量
                    VStack(alignment: .leading, spacing: 2) {
                        Text(check.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text("需要 x\(check.required)")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    Spacer()

                    // 库存状态
                    if offer.isAcceptable {
                        if check.sufficient {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                Text("足够 (\(check.owned))")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(ApocalypseTheme.success)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                Text("缺少\(check.required - check.owned)个")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(ApocalypseTheme.danger)
                        }
                    }
                }
                .padding(10)
                .background(ApocalypseTheme.background.opacity(0.5))
                .cornerRadius(8)
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 留言卡片

    private func messageCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "message.fill")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text("卖家留言")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 接受交易按钮

    private var acceptButton: some View {
        Button {
            showAcceptConfirmation = true
        } label: {
            HStack {
                if isAccepting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text("接受交易")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canAccept ? ApocalypseTheme.success : ApocalypseTheme.textMuted)
            .cornerRadius(12)
        }
        .disabled(!canAccept || isAccepting)
    }

    // MARK: - 确认信息

    private var acceptConfirmMessage: String {
        let offering = offer.offeringItems.map { "\($0.displayName) x\($0.quantity)" }.joined(separator: ", ")
        let requesting = offer.requestingItems.map { "\($0.displayName) x\($0.quantity)" }.joined(separator: ", ")
        return "你将付出: \(requesting)\n你将获得: \(offering)"
    }

    // MARK: - 接受交易操作

    private func acceptOffer() {
        isAccepting = true
        Task {
            do {
                try await tradeManager.acceptTradeOffer(offerId: offer.id)
                alertMessage = "交易成功！物品已入背包"
                didSucceed = true
                showAlert = true
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
            isAccepting = false
        }
    }

    // MARK: - 子组件

    private func itemDetailRow(item: TradeItem) -> some View {
        let def = MockExplorationData.getItemDefinition(by: item.itemId)
        let category = def?.category ?? .misc

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(categoryColor(category).opacity(0.2))
                    .frame(width: 38, height: 38)
                Image(systemName: categoryIcon(category))
                    .font(.system(size: 15))
                    .foregroundColor(categoryColor(category))
            }

            Text(item.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            Text("x\(item.quantity)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(10)
        .background(ApocalypseTheme.background.opacity(0.5))
        .cornerRadius(8)
    }

    private func statusBadge(status: TradeOfferStatus) -> some View {
        Text(status.displayName)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status))
            .cornerRadius(6)
    }

    private func statusColor(_ status: TradeOfferStatus) -> Color {
        switch status {
        case .active: return ApocalypseTheme.success
        case .completed: return ApocalypseTheme.info
        case .cancelled: return ApocalypseTheme.textMuted
        case .expired: return ApocalypseTheme.danger
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
