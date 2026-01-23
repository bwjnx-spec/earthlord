//
//  ExplorationResultView.swift
//  earthlord
//
//  探索会话结束后显示收获的弹窗页面
//  展示本次探索的统计数据和获得的物品
//

import SwiftUI

struct ExplorationResultView: View {

    // MARK: - 属性

    /// 探索会话结果数据（可选，如果为nil表示探索失败）
    let sessionResult: ExplorationSessionResult?

    /// 错误信息（探索失败时显示）
    let errorMessage: String?

    /// 重试回调
    let onRetry: (() -> Void)?

    /// 环境变量：关闭页面
    @Environment(\.dismiss) private var dismiss

    // MARK: - 动画状态

    /// 动画进度（0-1），用于数字跳动
    @State private var animationProgress: Double = 0

    /// 已显示的物品索引集合
    @State private var visibleItemIndices: Set<Int> = []

    /// 页面是否已出现
    @State private var hasAppeared = false

    // MARK: - 便捷初始化器

    /// 成功结果初始化器
    init(sessionResult: ExplorationSessionResult) {
        self.sessionResult = sessionResult
        self.errorMessage = nil
        self.onRetry = nil
    }

    /// 失败结果初始化器
    init(errorMessage: String, onRetry: @escaping () -> Void) {
        self.sessionResult = nil
        self.errorMessage = errorMessage
        self.onRetry = onRetry
    }

    // MARK: - 计算属性

    /// 格式化距离（米 → 公里）
    private func formatDistance(_ meters: Double) -> String {
        let km = meters / 1000.0
        return String(format: "%.2f", km)
    }

    /// 格式化面积（平方米 → 平方公里）
    private func formatArea(_ squareMeters: Double) -> String {
        let squareKm = squareMeters / 1_000_000.0
        return String(format: "%.3f", squareKm)
    }

    /// 格式化时长（秒 → 分钟）
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    // MARK: - 视图主体

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                // 根据是否有错误显示不同内容
                if let error = errorMessage {
                    // 错误状态
                    errorStateView(message: error)
                } else if let result = sessionResult {
                    // 成功状态
                    successContentView(result: result)
                }
            }
            .navigationTitle("探索结果")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true

                // 只有成功时才执行动画
                if let result = sessionResult {
                    // 数字跳动动画（1秒内从0到目标值）
                    withAnimation(.easeOut(duration: 1.0)) {
                        animationProgress = 1.0
                    }

                    // 物品依次出现动画
                    for index in result.itemsCollected.indices {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(index) * 0.2) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                _ = visibleItemIndices.insert(index)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 错误状态视图

    /// 探索失败时显示的错误状态
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // 错误图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.danger.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.danger)
            }

            // 标题
            Text("探索失败")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 错误信息
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // 按钮区域
            VStack(spacing: 12) {
                // 重试按钮
                if let retry = onRetry {
                    Button(action: retry) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18))

                            Text("重试")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(
                                colors: [
                                    ApocalypseTheme.primary,
                                    ApocalypseTheme.primaryDark
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                }

                // 返回按钮
                Button(action: {
                    dismiss()
                }) {
                    Text("返回")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    // MARK: - 成功内容视图

    /// 探索成功时显示的内容
    private func successContentView(result: ExplorationSessionResult) -> some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 成就标题区域
                    achievementHeader
                        .padding(.top, 20)

                    // 统计数据卡片
                    statisticsCard
                        .padding(.horizontal, 16)

                    // 获得物品卡片
                    itemsCard
                        .padding(.horizontal, 16)

                    // 底部间距
                    Spacer(minLength: 80)
                }
            }
            .scrollIndicators(.hidden)

            // 确认按钮（固定在底部）
            VStack {
                Spacer()

                confirmButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            }
        }
    }

    // MARK: - 成就标题区域

    /// 成就标题区域（带仪式感）
    private var achievementHeader: some View {
        VStack(spacing: 16) {
            // 大地图图标（带渐变圆形背景）
            ZStack {
                // 外圈渐变光环
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary.opacity(0.3),
                                ApocalypseTheme.primary.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)

                // 内圈渐变背景
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)

                // 地图图标
                Image(systemName: "map.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            // "探索完成！"大标题
            Text("探索完成！")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            ApocalypseTheme.primary,
                            ApocalypseTheme.primaryDark
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // 副标题
            Text("本次探索收获丰富")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 统计数据卡片

    /// 统计数据卡片
    private var statisticsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 卡片标题
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("探索统计")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            if let result = sessionResult {
                // 行走距离（带数字跳动动画）
                AnimatedStatisticRow(
                    icon: "figure.walk",
                    title: "行走距离",
                    currentValue: result.walkDistance,
                    totalValue: result.totalWalkDistance,
                    rank: result.walkDistanceRank,
                    animationProgress: animationProgress,
                    formatter: { formatDistance($0) + " km" }
                )

                // 探索面积（带数字跳动动画）
                AnimatedStatisticRow(
                    icon: "map",
                    title: "探索面积",
                    currentValue: result.exploredArea,
                    totalValue: result.totalExploredArea,
                    rank: result.exploredAreaRank,
                    animationProgress: animationProgress,
                    formatter: { formatArea($0) + " km²" }
                )

                // 探索时长
                HStack(spacing: 12) {
                    // 图标
                    Image(systemName: "clock.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.info)
                        .frame(width: 32)

                    // 信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text("探索时长")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(formatDuration(result.duration))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 获得物品卡片

    /// 获得物品卡片
    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 卡片标题
            HStack(spacing: 8) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.warning)

                Text("获得物品")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 物品列表
            if let result = sessionResult {
                if result.itemsCollected.isEmpty {
                    // 空状态
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundColor(ApocalypseTheme.textMuted)

                            Text("本次探索未获得物品")
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                } else {
                    ForEach(Array(result.itemsCollected.enumerated()), id: \.element.id) { index, item in
                        if let definition = MockExplorationData.getItemDefinition(by: item.definitionId) {
                            AnimatedItemRow(
                                item: item,
                                definition: definition,
                                isVisible: visibleItemIndices.contains(index)
                            )
                        }
                    }

                    // 底部提示（所有物品显示后出现）
                    if visibleItemIndices.count == result.itemsCollected.count {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.success)

                            Text("已添加到背包")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ApocalypseTheme.success)
                        }
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 确认按钮

    /// 确认按钮
    private var confirmButton: some View {
        Button(action: {
            dismiss()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))

                Text("确认")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [
                        ApocalypseTheme.primary,
                        ApocalypseTheme.primaryDark
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 8, y: 4)
        }
    }
}

// MARK: - 统计行组件

/// 单个统计数据行
struct StatisticRow: View {
    let icon: String
    let title: String
    let currentValue: String
    let totalValue: String
    let rank: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // 图标
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.info)
                    .frame(width: 32)

                // 标题
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 排名（绿色醒目显示）
                Text("#\(rank)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.success)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.success.opacity(0.15))
                    .cornerRadius(8)
            }

            // 本次 / 累计数值
            HStack(spacing: 16) {
                // 左边缩进（对齐图标）
                Spacer()
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("本次:")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(currentValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.primary)
                    }

                    HStack(spacing: 8) {
                        Text("累计:")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(totalValue)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }

                Spacer()
            }
        }
    }
}

// MARK: - 物品行组件

/// 单个物品行
struct ItemRow: View {
    let item: InventoryItem
    let definition: ItemDefinition

    /// 获取分类对应的颜色
    private var categoryColor: Color {
        switch definition.category {
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
    private var categoryIcon: String {
        switch definition.category {
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

    var body: some View {
        HStack(spacing: 12) {
            // 左侧圆形图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: categoryIcon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }

            // 物品名称和数量
            VStack(alignment: .leading, spacing: 4) {
                Text(definition.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("x\(item.quantity)")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 右侧绿色对勾
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(ApocalypseTheme.success)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 动画统计行组件

/// 带数字跳动动画的统计行
struct AnimatedStatisticRow: View {
    let icon: String
    let title: String
    let currentValue: Double
    let totalValue: Double
    let rank: Int
    let animationProgress: Double
    let formatter: (Double) -> String

    /// 动画后的当前值
    private var animatedCurrentValue: Double {
        currentValue * animationProgress
    }

    /// 动画后的累计值
    private var animatedTotalValue: Double {
        totalValue * animationProgress
    }

    /// 动画后的排名
    private var animatedRank: Int {
        Int(Double(rank) * animationProgress)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // 图标
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.info)
                    .frame(width: 32)

                // 标题
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 排名（绿色醒目显示，带跳动效果）
                Text("#\(animatedRank)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.success)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.success.opacity(0.15))
                    .cornerRadius(8)
                    .contentTransition(.numericText())
            }

            // 本次 / 累计数值
            HStack(spacing: 16) {
                // 左边缩进（对齐图标）
                Spacer()
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("本次:")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(formatter(animatedCurrentValue))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.primary)
                            .contentTransition(.numericText())
                    }

                    HStack(spacing: 8) {
                        Text("累计:")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(formatter(animatedTotalValue))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .contentTransition(.numericText())
                    }
                }

                Spacer()
            }
        }
    }
}

// MARK: - 动画物品行组件

/// 带出现动画和弹跳对勾的物品行
struct AnimatedItemRow: View {
    let item: InventoryItem
    let definition: ItemDefinition
    let isVisible: Bool

    /// 对勾弹跳动画状态
    @State private var checkmarkScale: CGFloat = 0

    /// 获取分类对应的颜色
    private var categoryColor: Color {
        switch definition.category {
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
    private var categoryIcon: String {
        switch definition.category {
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

    var body: some View {
        HStack(spacing: 12) {
            // 左侧圆形图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: categoryIcon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }

            // 物品名称和数量
            VStack(alignment: .leading, spacing: 4) {
                Text(definition.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("x\(item.quantity)")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 右侧绿色对勾（带弹跳效果）
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(checkmarkScale)
        }
        .padding(.vertical, 8)
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : 30)
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                // 对勾弹跳动画
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    checkmarkScale = 1.0
                }
            }
        }
    }
}

// MARK: - 预览

#Preview("成功状态") {
    ExplorationResultView(
        sessionResult: MockExplorationData.mockExplorationSessionResult
    )
}

#Preview("失败状态") {
    ExplorationResultView(
        errorMessage: "网络连接失败，请检查网络设置后重试",
        onRetry: {
            print("重试探索")
        }
    )
}
