//
//  ChannelChatView.swift
//  earthlord
//
//  频道聊天界面
//

import SwiftUI
import CoreLocation

struct ChannelChatView: View {

    let channel: CommunicationChannel

    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var communicationManager = CommunicationManager.shared

    @State private var messageText = ""
    @State private var isFirstLoad = true

    private var currentUserId: UUID? {
        guard let idStr = authManager.currentUser?.id else { return nil }
        return UUID(uuidString: idStr)
    }

    private var senderName: String {
        authManager.currentUser?.email?.components(separatedBy: "@").first ?? "未知幸存者"
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 消息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if communicationManager.channelMessages.isEmpty && !isFirstLoad {
                                emptyMessagesView
                            }

                            ForEach(communicationManager.channelMessages) { message in
                                MessageBubbleView(
                                    message: message,
                                    isMine: message.isMine(userId: currentUserId ?? UUID())
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: communicationManager.channelMessages.count) { _, _ in
                        if let lastMessage = communicationManager.channelMessages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider().background(ApocalypseTheme.textSecondary.opacity(0.3))

                // 输入区域
                inputBar
            }
        }
        .navigationTitle(channel.channelName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: ChannelDetailView(channel: channel).environmentObject(authManager)) {
                    Image(systemName: "info.circle")
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .onAppear {
            Task {
                await communicationManager.loadChannelMessages(channelId: channel.id)
                isFirstLoad = false
                await communicationManager.subscribeToMessages(channelId: channel.id, channelType: channel.channelType)
            }
        }
        .onDisappear {
            communicationManager.clearMessages()
        }
    }

    // MARK: - 空消息提示

    private var emptyMessagesView: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text("暂无消息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text("发送第一条消息，开始聊天吧")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("输入消息...", text: $messageText)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(20)

            Button(action: { Task { await sendMessage() } }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(canSend ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ApocalypseTheme.background)
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !communicationManager.isSendingMessage
    }

    // MARK: - 发送消息

    private func sendMessage() async {
        guard let userId = currentUserId else { return }
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messageText = ""

        let location = LocationManager.shared.userLocation
        _ = await communicationManager.sendMessage(
            channelId: channel.id,
            senderId: userId,
            senderName: senderName,
            content: text,
            latitude: location?.latitude,
            longitude: location?.longitude
        )
    }
}

// MARK: - 消息气泡

private struct MessageBubbleView: View {

    let message: ChannelMessage
    let isMine: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMine { Spacer(minLength: 60) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                // 发送者名称（仅他人消息显示）
                if !isMine {
                    Text(message.senderName)
                        .font(.caption2).fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 消息内容
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isMine ? .white : ApocalypseTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isMine ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                    .cornerRadius(16, corners: isMine ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])

                // 时间
                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
            }

            if !isMine { Spacer(minLength: 60) }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 圆角扩展

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

private struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
