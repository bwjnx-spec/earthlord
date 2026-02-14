//
//  CommunicationManager.swift
//  earthlord
//
//  通讯管理器 - 管理通讯设备的加载、切换、解锁
//

import Foundation
import Combine
import Supabase

@MainActor
final class CommunicationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = CommunicationManager()

    // MARK: - Published Properties

    @Published private(set) var devices: [CommunicationDevice] = []
    @Published private(set) var currentDevice: CommunicationDevice?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var channels: [CommunicationChannel] = []
    @Published private(set) var subscribedChannels: [CommunicationChannel] = []
    @Published private(set) var mySubscriptions: [ChannelSubscription] = []

    // MARK: - Private

    private let client = supabaseClient

    private init() {}

    // MARK: - 加载设备

    func loadDevices(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [CommunicationDevice] = try await client
                .from("communication_devices")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            devices = response
            currentDevice = devices.first(where: { $0.isCurrent })

            if devices.isEmpty {
                await initializeDevices(userId: userId)
            }
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 初始化设备

    func initializeDevices(userId: UUID) async {
        do {
            try await client
                .rpc("initialize_user_devices", params: ["p_user_id": userId.uuidString])
                .execute()
            await loadDevices(userId: userId)
        } catch {
            errorMessage = "初始化失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 切换设备

    func switchDevice(userId: UUID, to deviceType: DeviceType) async {
        guard let device = devices.first(where: { $0.deviceType == deviceType }),
              device.isUnlocked else {
            errorMessage = "设备未解锁"
            return
        }

        if device.isCurrent { return }

        isLoading = true

        do {
            try await client
                .rpc("switch_current_device", params: [
                    "p_user_id": userId.uuidString,
                    "p_device_type": deviceType.rawValue
                ])
                .execute()

            for i in devices.indices {
                devices[i].isCurrent = (devices[i].deviceType == deviceType)
            }
            currentDevice = devices.first(where: { $0.deviceType == deviceType })
        } catch {
            errorMessage = "切换失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 解锁设备（由建造系统调用）

    func unlockDevice(userId: UUID, deviceType: DeviceType) async {
        do {
            let updateData = DeviceUnlockUpdate(
                isUnlocked: true,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )

            try await client
                .from("communication_devices")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .eq("device_type", value: deviceType.rawValue)
                .execute()

            if let index = devices.firstIndex(where: { $0.deviceType == deviceType }) {
                devices[index].isUnlocked = true
            }
        } catch {
            errorMessage = "解锁失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 便捷查询

    func getCurrentDeviceType() -> DeviceType {
        currentDevice?.deviceType ?? .walkieTalkie
    }

    func canSendMessage() -> Bool {
        currentDevice?.deviceType.canSend ?? false
    }

    func getCurrentRange() -> Double {
        currentDevice?.deviceType.range ?? 3.0
    }

    func isDeviceUnlocked(_ deviceType: DeviceType) -> Bool {
        devices.first(where: { $0.deviceType == deviceType })?.isUnlocked ?? false
    }

    // MARK: - 频道管理

    func loadPublicChannels() async {
        do {
            let response: [CommunicationChannel] = try await client
                .from("communication_channels")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            channels = response
        } catch {
            errorMessage = "加载频道失败: \(error.localizedDescription)"
        }
    }

    func loadSubscribedChannels(userId: UUID) async {
        do {
            let subs: [ChannelSubscription] = try await client
                .from("channel_subscriptions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            mySubscriptions = subs

            if subs.isEmpty {
                subscribedChannels = []
                return
            }

            let channelIds = subs.map { $0.channelId.uuidString }
            let channelResponse: [CommunicationChannel] = try await client
                .from("communication_channels")
                .select()
                .in("id", values: channelIds)
                .execute()
                .value
            subscribedChannels = channelResponse
        } catch {
            errorMessage = "加载订阅频道失败: \(error.localizedDescription)"
        }
    }

    func createChannel(creatorId: UUID, name: String, type: ChannelType, description: String) async -> Bool {
        do {
            let payload = CreateChannelPayload(
                creatorId: creatorId,
                channelName: name,
                channelType: type,
                description: description
            )
            try await client
                .from("communication_channels")
                .insert(payload)
                .execute()

            // 重新加载频道列表获取新建频道
            await loadPublicChannels()

            // 自动订阅创建者
            if let newChannel = channels.first(where: { $0.channelName == name && $0.creatorId == creatorId }) {
                await subscribeToChannel(channelId: newChannel.id, userId: creatorId)
            }

            return true
        } catch {
            errorMessage = "创建频道失败: \(error.localizedDescription)"
            return false
        }
    }

    func subscribeToChannel(channelId: UUID, userId: UUID) async {
        do {
            try await client
                .rpc("subscribe_to_channel", params: [
                    "p_channel_id": channelId.uuidString,
                    "p_user_id": userId.uuidString
                ])
                .execute()
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)
        } catch {
            errorMessage = "订阅失败: \(error.localizedDescription)"
        }
    }

    func unsubscribeFromChannel(channelId: UUID, userId: UUID) async {
        do {
            try await client
                .rpc("unsubscribe_from_channel", params: [
                    "p_channel_id": channelId.uuidString,
                    "p_user_id": userId.uuidString
                ])
                .execute()
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)
        } catch {
            errorMessage = "取消订阅失败: \(error.localizedDescription)"
        }
    }

    func isSubscribed(channelId: UUID) -> Bool {
        mySubscriptions.contains(where: { $0.channelId == channelId })
    }

    func deleteChannel(channelId: UUID) async {
        do {
            try await client
                .from("communication_channels")
                .delete()
                .eq("id", value: channelId.uuidString)
                .execute()
            await loadPublicChannels()
        } catch {
            errorMessage = "删除频道失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - Update Models

private struct DeviceUnlockUpdate: Encodable {
    let isUnlocked: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case isUnlocked = "is_unlocked"
        case updatedAt = "updated_at"
    }
}

private struct CreateChannelPayload: Encodable {
    let creatorId: UUID
    let channelName: String
    let channelType: ChannelType
    let description: String

    enum CodingKeys: String, CodingKey {
        case creatorId = "creator_id"
        case channelName = "channel_name"
        case channelType = "channel_type"
        case description
    }
}
