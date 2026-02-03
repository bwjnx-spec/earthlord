//
//  GeohashUtil.swift
//  earthlord
//
//  Created for POI procedural generation
//

import Foundation
import CoreLocation

/// Geohash 编码/解码工具
/// 用于将 GPS 坐标转换为网格单元标识符
struct GeohashUtil {
    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    /// 将坐标编码为 geohash 字符串
    /// - Parameters:
    ///   - latitude: 纬度（-90 到 90）
    ///   - longitude: 经度（-180 到 180）
    ///   - precision: 精度等级（1-12，推荐 6 约为 1.2km × 0.6km）
    /// - Returns: geohash 字符串
    static func encode(latitude: Double, longitude: Double, precision: Int = 6) -> String {
        var geohash = ""
        var evenBit = true
        var bit = 0
        var ch = 0

        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)

        while geohash.count < precision {
            if evenBit {
                // 处理经度
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude > mid {
                    ch |= (1 << (4 - bit))
                    lonRange.0 = mid
                } else {
                    lonRange.1 = mid
                }
            } else {
                // 处理纬度
                let mid = (latRange.0 + latRange.1) / 2
                if latitude > mid {
                    ch |= (1 << (4 - bit))
                    latRange.0 = mid
                } else {
                    latRange.1 = mid
                }
            }

            evenBit = !evenBit

            if bit < 4 {
                bit += 1
            } else {
                geohash.append(base32[ch])
                bit = 0
                ch = 0
            }
        }

        return geohash
    }

    /// 将 geohash 字符串解码为坐标
    /// - Parameter geohash: geohash 字符串
    /// - Returns: (纬度, 经度) 元组（返回网格中心点）
    static func decode(geohash: String) -> (latitude: Double, longitude: Double) {
        var evenBit = true
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)

        for char in geohash.lowercased() {
            guard let idx = base32.firstIndex(of: char) else { continue }
            let value = base32.distance(from: base32.startIndex, to: idx)

            for bitIndex in (0..<5).reversed() {
                let bit = (value >> bitIndex) & 1

                if evenBit {
                    // 处理经度
                    let mid = (lonRange.0 + lonRange.1) / 2
                    if bit == 1 {
                        lonRange.0 = mid
                    } else {
                        lonRange.1 = mid
                    }
                } else {
                    // 处理纬度
                    let mid = (latRange.0 + latRange.1) / 2
                    if bit == 1 {
                        latRange.0 = mid
                    } else {
                        latRange.1 = mid
                    }
                }

                evenBit = !evenBit
            }
        }

        let latitude = (latRange.0 + latRange.1) / 2
        let longitude = (lonRange.0 + lonRange.1) / 2

        return (latitude, longitude)
    }

    /// 获取 geohash 单元的边界框
    /// - Parameter geohash: geohash 字符串
    /// - Returns: (最小经度, 最小纬度, 最大经度, 最大纬度)
    static func bounds(geohash: String) -> (minLon: Double, minLat: Double, maxLon: Double, maxLat: Double) {
        var evenBit = true
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)

        for char in geohash.lowercased() {
            guard let idx = base32.firstIndex(of: char) else { continue }
            let value = base32.distance(from: base32.startIndex, to: idx)

            for bitIndex in (0..<5).reversed() {
                let bit = (value >> bitIndex) & 1

                if evenBit {
                    let mid = (lonRange.0 + lonRange.1) / 2
                    if bit == 1 {
                        lonRange.0 = mid
                    } else {
                        lonRange.1 = mid
                    }
                } else {
                    let mid = (latRange.0 + latRange.1) / 2
                    if bit == 1 {
                        latRange.0 = mid
                    } else {
                        latRange.1 = mid
                    }
                }

                evenBit = !evenBit
            }
        }

        return (lonRange.0, latRange.0, lonRange.1, latRange.1)
    }
}
