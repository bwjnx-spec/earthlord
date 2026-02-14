//
//  TradeMarketView.swift
//  earthlord
//
//  交易市场主视图
//  包含市场挂单、我的挂单、交易历史三个子页面
//

import SwiftUI

struct TradeMarketView: View {

    // MARK: - 子页面枚举

    enum TradeTab: Int, CaseIterable {
        case market = 0
        case myOffers
        case history

        var title: String {
            switch self {
            case .market: return "市场"
            case .myOffers: return "我的挂单"
            case .history: return "历史"
            }
        }
    }

    // MARK: - 状态

    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var tradeManager = TradeManager.shared

    @State private var selectedTab: TradeTab = .market
    @State private var showCreateOffer = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    // 导航 + 评价 + 取消确认
    @State private var selectedOffer: TradeOffer?
    @State private var selectedHistoryForRating: TradeHistory?
    @State private var offerToCancel: TradeOffer?
    @State private var showCancelConfirmation = false

    // MARK: - 视图主体

    var body: some View {
        VStack(spacing: 0) {
            // 子页面切换
            tabBar
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

            // 内容
            switch selectedTab {
            case .market:
                marketView
            case .myOffers:
                myOffersView
            case .history:
                historyView
            }
        }
        .onAppear {
            Task {
                await tradeManager.loadAvailableOffers()
                await tradeManager.loadMyOffers()
                await tradeManager.loadTradeHistory()
                await tradeManager.checkAndExpireOffers()
            }
        }
        .navigationDestination(item: $selectedOffer) { offer in
            TradeOfferDetailView(offer: offer)
        }
        .sheet(isPresented: $showCreateOffer) {
            CreateTradeOfferView()
        }
        .sheet(item: $selectedHistoryForRating) { history in
            TradeRatingSheetView(history: history)
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .alert("取消挂单", isPresented: $showCancelConfirmation) {
            Button("取消", role: .cancel) {}
            Button("确认取消", role: .destructive) { cancelOffer() }
        } message: {
            Text("确定要取消吗？物品将退还到背包。")
        }
    }

    // MARK: - 子页面切换栏

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(TradeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 14, weight: selectedTab == tab ? .bold : .medium))
                        .foregroundColor(selectedTab == tab ? .white : ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab
                                ? ApocalypseTheme.primary
                                : ApocalypseTheme.cardBackground
                        )
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - 市场视图

    private var marketView: some View {
        Group {
            if tradeManager.isLoading {
                loadingView
            } else if tradeManager.availableOffers.isEmpty {
                emptyView(icon: "storefront", title: "暂无挂单", subtitle: "市场上还没有交易挂单")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(tradeManager.availableOffers) { offer in
                            tradeOfferCard(offer: offer, isMyOffer: false)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .refreshable {
            await tradeManager.loadAvailableOffers()
        }
    }

    // MARK: - 我的挂单视图

    private var myOffersView: some View {
        VStack(spacing: 0) {
            // 发布按钮
            Button {
                showCreateOffer = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("发布新挂单")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ApocalypseTheme.primary)
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if tradeManager.isLoading {
                loadingView
            } else if tradeManager.myOffers.isEmpty {
                emptyView(icon: "tag", title: "暂无挂单", subtitle: "点击上方按钮发布交易")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(tradeManager.myOffers) { offer in
                            tradeOfferCard(offer: offer, isMyOffer: true)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .refreshable {
            await tradeManager.loadMyOffers()
        }
    }

    // MARK: - 历史视图

    private var historyView: some View {
        Group {
            if tradeManager.isLoading {
                loadingView
            } else if tradeManager.tradeHistory.isEmpty {
                emptyView(icon: "clock.arrow.circlepath", title: "暂无记录", subtitle: "完成交易后会在这里显示")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(tradeManager.tradeHistory) { history in
                            tradeHistoryCard(history: history)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .refreshable {
            await tradeManager.loadTradeHistory()
        }
    }

    // MARK: - 挂单卡片

    private func tradeOfferCard(offer: TradeOffer, isMyOffer: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：状态 + 剩余时间
            HStack {
                statusBadge(status: offer.status)

                Spacer()

                if offer.status == .active {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(offer.formattedRemainingTime)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(offer.isExpired ? ApocalypseTheme.danger : ApocalypseTheme.textSecondary)
                }
            }

            // 交换内容
            HStack(spacing: 8) {
                // 提供的物品
                VStack(alignment: .leading, spacing: 4) {
                    Text("出售")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ApocalypseTheme.primary)
                    ForEach(offer.offeringItems) { item in
                        tradeItemRow(item: item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 箭头
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.primary)

                // 请求的物品
                VStack(alignment: .leading, spacing: 4) {
                    Text("求购")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ApocalypseTheme.info)
                    ForEach(offer.requestingItems) { item in
                        tradeItemRow(item: item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 留言
            if let message = offer.message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineLimit(2)
            }

            // 操作按钮
            if isMyOffer {
                if offer.status == .active {
                    Button {
                        offerToCancel = offer
                        showCancelConfirmation = true
                    } label: {
                        Text("取消挂单")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ApocalypseTheme.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(ApocalypseTheme.danger.opacity(0.15))
                            .cornerRadius(8)
                    }
                }
            } else {
                // 市场卡片：点击查看详情
                Button {
                    selectedOffer = offer
                } label: {
                    HStack {
                        Text("查看详情")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ApocalypseTheme.primary.opacity(0.15))
                    .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 取消挂单操作

    private func cancelOffer() {
        guard let offer = offerToCancel else { return }
        Task {
            do {
                try await tradeManager.cancelTradeOffer(offerId: offer.id)
                alertMessage = "挂单已取消，物品已退还"
                showAlert = true
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    // MARK: - 交易历史卡片

    private func tradeHistoryCard(history: TradeHistory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶部
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(ApocalypseTheme.success)
                Text("交易完成")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.success)

                Spacer()

                Text(history.completedAt, style: .date)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 交换物品
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("出售方")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ApocalypseTheme.primary)
                    ForEach(history.offeringItems) { item in
                        tradeItemRow(item: item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)

                VStack(alignment: .leading, spacing: 4) {
                    Text("购买方")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ApocalypseTheme.info)
                    ForEach(history.requestingItems) { item in
                        tradeItemRow(item: item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 评分
            if history.sellerRating != nil || history.buyerRating != nil {
                HStack(spacing: 16) {
                    if let rating = history.sellerRating {
                        ratingView(label: "卖家评分", rating: rating)
                    }
                    if let rating = history.buyerRating {
                        ratingView(label: "买家评分", rating: rating)
                    }
                }
            }

            // 去评价按钮
            if let userId = authManager.currentUser?.id {
                let isSeller = history.sellerId.uuidString == userId
                let isBuyer = history.buyerId.uuidString == userId
                let canRate = (isSeller && history.sellerRating == nil) || (isBuyer && history.buyerRating == nil)

                if canRate {
                    Button {
                        selectedHistoryForRating = history
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 13))
                            Text("去评价")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(ApocalypseTheme.warning)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(ApocalypseTheme.warning.opacity(0.15))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 子组件

    private func tradeItemRow(item: TradeItem) -> some View {
        HStack(spacing: 6) {
            Text(item.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text("x\(item.quantity)")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
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

    private func ratingView(label: String, rating: Int) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(ApocalypseTheme.textSecondary)
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: 10))
                    .foregroundColor(ApocalypseTheme.warning)
            }
        }
    }

    // MARK: - 加载 / 空状态

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(ApocalypseTheme.primary)
            Text("加载中...")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func emptyView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
