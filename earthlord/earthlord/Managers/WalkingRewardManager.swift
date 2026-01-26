//
//  WalkingRewardManager.swift
//  earthlord
//
//  行走奖励管理器 - 管理行走距离奖励、每日目标、成就系统
//  功能：
//  1. 计算行走奖励（经验值、货币）
//  2. 管理每日行走目标
//  3. 追踪行走成就
//  4. 提供奖励提示
//

import Foundation
import Combine

/// 行走奖励管理器
@MainActor
class WalkingRewardManager: ObservableObject {

    // MARK: - 单例

    static let shared = WalkingRewardManager()

    // MARK: - 发布属性

    /// 今日行走目标进度（0.0 - 1.0）
    @Published var dailyGoalProgress: Double = 0.0

    /// 今日是否已达成目标
    @Published var dailyGoalAchieved: Bool = false

    /// 今日累计奖励经验值
    @Published var todayRewardExp: Int = 0

    /// 今日累计奖励货币
    @Published var todayRewardCurrency: Int = 0

    /// 当前解锁的行走成就
    @Published var unlockedAchievements: [WalkingAchievement] = []

    /// 待领取的成就奖励
    @Published var pendingAchievementRewards: [WalkingAchievement] = []

    // MARK: - 私有属性

    private var cancellables = Set<AnyCancellable>()

    /// 每日行走目标（米）
    private let dailyWalkingGoal: Double = 5000.0  // 5km

    /// 每米行走奖励经验值
    private let expPerMeter: Double = 0.1

    /// 每米行走奖励货币
    private let currencyPerMeter: Double = 0.05

    /// 所有行走成就定义
    private let allAchievements: [WalkingAchievement] = [
        // 初级成就
        WalkingAchievement(
            id: "walk_100m",
            name: "初次漫步",
            description: "累计行走 100 米",
            requiredDistance: 100,
            rewardExp: 50,
            rewardCurrency: 20,
            icon: "figure.walk"
        ),
        WalkingAchievement(
            id: "walk_1km",
            name: "探索者",
            description: "累计行走 1 公里",
            requiredDistance: 1000,
            rewardExp: 100,
            rewardCurrency: 50,
            icon: "figure.walk.circle"
        ),
        WalkingAchievement(
            id: "walk_5km",
            name: "远行者",
            description: "累计行走 5 公里",
            requiredDistance: 5000,
            rewardExp: 300,
            rewardCurrency: 150,
            icon: "figure.hiking"
        ),

        // 中级成就
        WalkingAchievement(
            id: "walk_10km",
            name: "徒步家",
            description: "累计行走 10 公里",
            requiredDistance: 10000,
            rewardExp: 500,
            rewardCurrency: 250,
            icon: "figure.outdoor.cycle"
        ),
        WalkingAchievement(
            id: "walk_50km",
            name: "长途旅者",
            description: "累计行走 50 公里",
            requiredDistance: 50000,
            rewardExp: 1500,
            rewardCurrency: 800,
            icon: "map"
        ),
        WalkingAchievement(
            id: "walk_100km",
            name: "环球行者",
            description: "累计行走 100 公里",
            requiredDistance: 100000,
            rewardExp: 3000,
            rewardCurrency: 1500,
            icon: "globe.asia.australia"
        ),

        // 高级成就
        WalkingAchievement(
            id: "walk_500km",
            name: "传奇旅者",
            description: "累计行走 500 公里",
            requiredDistance: 500000,
            rewardExp: 10000,
            rewardCurrency: 5000,
            icon: "crown"
        ),
        WalkingAchievement(
            id: "walk_1000km",
            name: "世界漫游者",
            description: "累计行走 1000 公里",
            requiredDistance: 1000000,
            rewardExp: 20000,
            rewardCurrency: 10000,
            icon: "star.circle.fill"
        )
    ]

    // MARK: - 初始化

    private init() {
        loadRewardData()
    }

    // MARK: - Public Methods

    /// 更新行走距离并计算奖励
    /// - Parameters:
    ///   - totalDistance: 总行走距离（米）
    ///   - todayDistance: 今日行走距离（米）
    func updateWalkingDistance(totalDistance: Double, todayDistance: Double) {
        // 更新每日目标进度
        dailyGoalProgress = min(todayDistance / dailyWalkingGoal, 1.0)

        // 检查是否达成每日目标
        if todayDistance >= dailyWalkingGoal && !dailyGoalAchieved {
            dailyGoalAchieved = true
            grantDailyGoalReward()
        }

        // 计算今日累计奖励（基于今日距离）
        todayRewardExp = Int(todayDistance * expPerMeter)
        todayRewardCurrency = Int(todayDistance * currencyPerMeter)

        // 检查成就解锁
        checkAchievements(totalDistance: totalDistance)

        // 保存数据
        saveRewardData()
    }

    /// 领取成就奖励
    /// - Parameter achievementId: 成就 ID
    func claimAchievementReward(achievementId: String) {
        guard let index = pendingAchievementRewards.firstIndex(where: { $0.id == achievementId }) else {
            return
        }

        let achievement = pendingAchievementRewards[index]

        // 移除待领取列表
        pendingAchievementRewards.remove(at: index)

        // TODO: 实际发放奖励到玩家账户
        print("🎁 领取成就奖励：\(achievement.name)")
        print("   - 经验值: +\(achievement.rewardExp)")
        print("   - 货币: +\(achievement.rewardCurrency)")

        // 保存数据
        saveRewardData()
    }

    /// 重置每日数据（新的一天调用）
    func resetDailyData() {
        dailyGoalProgress = 0.0
        dailyGoalAchieved = false
        todayRewardExp = 0
        todayRewardCurrency = 0

        saveRewardData()
        print("📊 每日行走奖励数据已重置")
    }

    // MARK: - Private Methods

    /// 检查并解锁成就
    private func checkAchievements(totalDistance: Double) {
        for achievement in allAchievements {
            // 跳过已解锁的成就
            if unlockedAchievements.contains(where: { $0.id == achievement.id }) {
                continue
            }

            // 跳过已在待领取列表中的成就
            if pendingAchievementRewards.contains(where: { $0.id == achievement.id }) {
                continue
            }

            // 检查是否达成条件
            if totalDistance >= achievement.requiredDistance {
                print("🏆 解锁新成就：\(achievement.name)")
                unlockedAchievements.append(achievement)
                pendingAchievementRewards.append(achievement)

                // TODO: 显示成就解锁动画/通知
            }
        }
    }

    /// 发放每日目标奖励
    private func grantDailyGoalReward() {
        let bonusExp = 200
        let bonusCurrency = 100

        todayRewardExp += bonusExp
        todayRewardCurrency += bonusCurrency

        print("🎉 达成每日行走目标！")
        print("   - 额外经验值: +\(bonusExp)")
        print("   - 额外货币: +\(bonusCurrency)")

        // TODO: 显示每日目标达成提示
    }

    /// 加载奖励数据
    private func loadRewardData() {
        // 加载每日目标状态
        dailyGoalAchieved = UserDefaults.standard.bool(forKey: "dailyGoalAchieved")

        // 加载今日奖励
        todayRewardExp = UserDefaults.standard.integer(forKey: "todayRewardExp")
        todayRewardCurrency = UserDefaults.standard.integer(forKey: "todayRewardCurrency")

        // 加载已解锁成就
        if let achievementIds = UserDefaults.standard.array(forKey: "unlockedAchievementIds") as? [String] {
            unlockedAchievements = allAchievements.filter { achievementIds.contains($0.id) }
        }

        // 加载待领取成就
        if let pendingIds = UserDefaults.standard.array(forKey: "pendingAchievementIds") as? [String] {
            pendingAchievementRewards = allAchievements.filter { pendingIds.contains($0.id) }
        }

        print("📊 行走奖励数据已加载")
        print("   - 今日经验: \(todayRewardExp)")
        print("   - 今日货币: \(todayRewardCurrency)")
        print("   - 已解锁成就: \(unlockedAchievements.count)")
        print("   - 待领取奖励: \(pendingAchievementRewards.count)")
    }

    /// 保存奖励数据
    private func saveRewardData() {
        UserDefaults.standard.set(dailyGoalAchieved, forKey: "dailyGoalAchieved")
        UserDefaults.standard.set(todayRewardExp, forKey: "todayRewardExp")
        UserDefaults.standard.set(todayRewardCurrency, forKey: "todayRewardCurrency")

        let unlockedIds = unlockedAchievements.map { $0.id }
        UserDefaults.standard.set(unlockedIds, forKey: "unlockedAchievementIds")

        let pendingIds = pendingAchievementRewards.map { $0.id }
        UserDefaults.standard.set(pendingIds, forKey: "pendingAchievementIds")
    }
}

// MARK: - Walking Achievement Model

/// 行走成就
struct WalkingAchievement: Identifiable {
    let id: String
    let name: String
    let description: String
    let requiredDistance: Double  // 所需行走距离（米）
    let rewardExp: Int           // 奖励经验值
    let rewardCurrency: Int      // 奖励货币
    let icon: String             // SF Symbol 图标名
}
