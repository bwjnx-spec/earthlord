//
//  CommunicationManager.swift
//  earthlord
//
//  通讯管理器 - 管理通讯设备的加载、切换、解锁
//

import Foundation
import Combine
import CoreLocation
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
    @Published private(set) var channelMessages: [ChannelMessage] = []
    @Published private(set) var isSendingMessage = false
    private var currentChannelType: ChannelType = .publicChannel
    private var messageSubscriptionTask: Task<Void, Never>?

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

    // MARK: - 消息管理

    func loadChannelMessages(channelId: UUID, limit: Int = 50) async {
        do {
            let response: [ChannelMessage] = try await client
                .from("channel_messages")
                .select()
                .eq("channel_id", value: channelId.uuidString)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            channelMessages = response.reversed()
        } catch {
            errorMessage = "加载消息失败: \(error.localizedDescription)"
        }
    }

    func sendMessage(channelId: UUID, senderId: UUID, senderName: String, content: String, latitude: Double? = nil, longitude: Double? = nil) async -> Bool {
        isSendingMessage = true
        defer { isSendingMessage = false }

        do {
            var params: [String: String] = [
                "p_channel_id": channelId.uuidString,
                "p_sender_id": senderId.uuidString,
                "p_sender_name": senderName,
                "p_content": content,
                "p_message_type": "text"
            ]
            if let lat = latitude, let lon = longitude {
                params["p_sender_lat"] = String(lat)
                params["p_sender_lon"] = String(lon)
            }
            params["p_sender_device_type"] = getCurrentDeviceType().rawValue

            try await client
                .rpc("send_channel_message", params: params)
                .execute()
            return true
        } catch {
            errorMessage = "发送失败: \(error.localizedDescription)"
            return false
        }
    }

    func subscribeToMessages(channelId: UUID, channelType: ChannelType = .publicChannel) async {
        unsubscribeFromMessages()
        currentChannelType = channelType

        messageSubscriptionTask = Task {
            let realtimeChannel = client.realtimeV2.channel("channel-messages-\(channelId.uuidString)")

            let insertions = await realtimeChannel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "channel_messages",
                filter: .eq("channel_id", value: channelId.uuidString)
            )

            try? await realtimeChannel.subscribeWithError()

            for await insertion in insertions {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let message = try insertion.decodeRecord(as: ChannelMessage.self, decoder: decoder)
                    guard self.shouldReceiveMessage(message) else {
                        print("🚫 [距离过滤] 消息被丢弃")
                        continue
                    }
                    if !self.channelMessages.contains(where: { $0.id == message.id }) {
                        self.channelMessages.append(message)
                    }
                } catch {
                    print("📡 Realtime 消息解码失败: \(error)")
                }
            }
        }
    }

    func unsubscribeFromMessages() {
        messageSubscriptionTask?.cancel()
        messageSubscriptionTask = nil
    }

    func clearMessages() {
        channelMessages = []
        unsubscribeFromMessages()
    }

    // MARK: - 距离过滤

    /// 主过滤入口：判断是否应该接收该消息
    private func shouldReceiveMessage(_ message: ChannelMessage) -> Bool {
        // 非公共频道不过滤
        guard currentChannelType == .publicChannel else {
            print("✅ [距离过滤] 非公共频道，直接通过")
            return true
        }

        // 无当前设备信息 → 保守策略，显示
        guard let myDevice = currentDevice else {
            print("✅ [距离过滤] 无当前设备信息，保守通过")
            return true
        }

        // 收音机接收方 → 无限制接收
        if myDevice.deviceType == .radio {
            print("✅ [距离过滤] 收音机接收，无限制通过")
            return true
        }

        // 无发送者设备类型 → 向后兼容，显示
        guard let senderDevice = message.senderDeviceType else {
            print("✅ [距离过滤] 无发送者设备类型，保守通过")
            return true
        }

        // 收音机不能发送
        if senderDevice == .radio {
            print("🚫 [距离过滤] 收音机不能发送消息")
            return false
        }

        // 无发送者位置 → 保守策略，显示
        guard let senderLocation = message.location else {
            print("✅ [距离过滤] 无发送者位置，保守通过")
            return true
        }

        // 无当前位置 → 保守策略，显示
        guard let myLocation = getCurrentLocation() else {
            print("✅ [距离过滤] 无当前位置，保守通过")
            return true
        }

        let distance = calculateDistance(
            from: LocationPoint(latitude: myLocation.latitude, longitude: myLocation.longitude),
            to: senderLocation
        )

        let result = canReceiveMessage(senderDevice: senderDevice, myDevice: myDevice.deviceType, distance: distance)
        print("\(result ? "✅" : "🚫") [距离过滤] 发送设备=\(senderDevice.displayName) 接收设备=\(myDevice.deviceType.displayName) 距离=\(String(format: "%.2f", distance))km")
        return result
    }

    /// 设备矩阵：根据双方设备类型和距离判断是否可接收
    private func canReceiveMessage(senderDevice: DeviceType, myDevice: DeviceType, distance: Double) -> Bool {
        // 收音机接收无限制
        if myDevice == .radio { return true }
        // 收音机不能发送
        if senderDevice == .radio { return false }
        // 取两端设备中较大 range 作为判定距离
        return distance <= max(senderDevice.range, myDevice.range)
    }

    /// 计算两个位置点之间的距离（公里）
    private func calculateDistance(from: LocationPoint, to: LocationPoint) -> Double {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2) / 1000.0
    }

    /// 获取当前位置
    private func getCurrentLocation() -> LocationPoint? {
        guard let coordinate = LocationManager.shared.userLocation else { return nil }
        return LocationPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
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
