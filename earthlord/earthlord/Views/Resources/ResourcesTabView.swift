//
//  ResourcesTabView.swift
//  earthlord
//
//  资源模块主入口页面
//  包含 POI、背包、已购、领地、交易等功能的分段导航
//

import SwiftUI

struct ResourcesTabView: View {

    // MARK: - 分段枚举

    /// 资源分段类型
    enum ResourceSegment: Int, CaseIterable {
        case poi = 0
        case backpack
        case purchased
        case territory
        case trade

        var title: String {
            switch self {
            case .poi: return "POI"
            case .backpack: return "背包"
            case .purchased: return "已购"
            case .territory: return "领地"
            case .trade: return "交易"
            }
        }
    }

    // MARK: - 状态

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .poi

    /// 交易开关状态（假数据）
    @State private var isTradeEnabled: Bool = false

    // MARK: - 视图主体

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 分段选择器
                    segmentPicker
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    // 内容区域
                    contentView
                }
            }
            .navigationTitle("资源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    tradeToggle
                }
            }
        }
    }

    // MARK: - 分段选择器

    /// 5 分段选择器
    private var segmentPicker: some View {
        Picker("资源分段", selection: $selectedSegment) {
            ForEach(ResourceSegment.allCases, id: \.self) { segment in
                Text(segment.title)
                    .tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .onAppear {
            // 设置分段选择器文字颜色，提高在深色背景下的可读性
            UISegmentedControl.appearance().setTitleTextAttributes(
                [.foregroundColor: UIColor.white], for: .normal
            )
            UISegmentedControl.appearance().setTitleTextAttributes(
                [.foregroundColor: UIColor.black], for: .selected
            )
            UISegmentedControl.appearance().backgroundColor = UIColor(white: 0.2, alpha: 1.0)
            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(
                red: 1.0, green: 0.4, blue: 0.1, alpha: 1.0
            )
        }
    }

    // MARK: - 交易开关

    /// 顶部交易开关
    private var tradeToggle: some View {
        HStack(spacing: 6) {
            Text("交易")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Toggle("", isOn: $isTradeEnabled)
                .labelsHidden()
                .tint(ApocalypseTheme.primary)
                .scaleEffect(0.8)
        }
    }

    // MARK: - 内容区域

    /// 根据选中分段显示对应内容
    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .poi:
            POIListView()

        case .backpack:
            BackpackView()

        case .purchased:
            placeholderView(title: "已购物品", icon: "bag.fill")

        case .territory:
            placeholderView(title: "领地资源", icon: "map.fill")

        case .trade:
            TradeMarketView()
        }
    }

    // MARK: - 占位视图

    /// 功能开发中占位视图
    private func placeholderView(title: String, icon: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(ApocalypseTheme.primary.opacity(0.5))
            }

            // 标题
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 提示文字
            Text("功能开发中")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 预览

#Preview {
    ResourcesTabView()
}
