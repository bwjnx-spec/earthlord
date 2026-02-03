//
//  SeededRandom.swift
//  earthlord
//
//  Created for deterministic POI generation
//

import Foundation

/// 基于种子的确定性伪随机数生成器
/// 使用线性同余生成器（LCG）算法
/// 相同种子始终产生相同的随机数序列
struct SeededRandom {
    private var state: UInt64

    // LCG 参数（使用 MMIX Donald Knuth 的参数）
    private let multiplier: UInt64 = 6364136223846793005
    private let increment: UInt64 = 1442695040888963407

    /// 使用种子初始化
    /// - Parameter seed: 种子值（相同种子产生相同序列）
    init(seed: UInt64) {
        self.state = seed
    }

    /// 使用字符串种子初始化（方便从 geohash 初始化）
    /// - Parameter seed: 字符串种子
    init(seed: String) {
        var hasher = Hasher()
        hasher.combine(seed)
        self.state = UInt64(bitPattern: Int64(hasher.finalize()))
    }

    /// 生成下一个随机数并更新状态
    /// - Returns: 0 到 UInt64.max 之间的随机整数
    mutating func next() -> UInt64 {
        state = state &* multiplier &+ increment
        return state
    }

    /// 生成 0.0 到 1.0 之间的随机浮点数
    /// - Returns: [0.0, 1.0) 范围内的随机 Double
    mutating func nextDouble() -> Double {
        let value = next()
        return Double(value) / Double(UInt64.max)
    }

    /// 生成指定范围内的随机整数
    /// - Parameter range: 整数范围
    /// - Returns: 范围内的随机整数
    mutating func nextInt(in range: Range<Int>) -> Int {
        let rangeSize = UInt64(range.count)
        let randomValue = next() % rangeSize
        return range.lowerBound + Int(randomValue)
    }

    /// 生成指定范围内的随机整数（闭区间）
    /// - Parameter range: 整数闭区间
    /// - Returns: 范围内的随机整数
    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let rangeSize = UInt64(range.count)
        let randomValue = next() % rangeSize
        return range.lowerBound + Int(randomValue)
    }

    /// 生成指定范围内的随机浮点数
    /// - Parameter range: 浮点数范围
    /// - Returns: 范围内的随机 Double
    mutating func nextDouble(in range: Range<Double>) -> Double {
        let random = nextDouble()
        return range.lowerBound + random * (range.upperBound - range.lowerBound)
    }

    /// 生成指定范围内的随机浮点数（闭区间）
    /// - Parameter range: 浮点数闭区间
    /// - Returns: 范围内的随机 Double
    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        let random = nextDouble()
        return range.lowerBound + random * (range.upperBound - range.lowerBound)
    }

    /// 从数组中随机选择一个元素
    /// - Parameter array: 源数组
    /// - Returns: 随机选择的元素（数组为空时返回 nil）
    mutating func choose<T>(from array: [T]) -> T? {
        guard !array.isEmpty else { return nil }
        let index = nextInt(in: 0..<array.count)
        return array[index]
    }

    /// 打乱数组顺序（Fisher-Yates 洗牌算法）
    /// - Parameter array: 要打乱的数组
    /// - Returns: 打乱后的新数组
    mutating func shuffle<T>(_ array: [T]) -> [T] {
        var result = array
        for i in (1..<result.count).reversed() {
            let j = nextInt(in: 0...i)
            result.swapAt(i, j)
        }
        return result
    }
}
