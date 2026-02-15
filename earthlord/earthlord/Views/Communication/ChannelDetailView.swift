//
//  ChannelDetailView.swift
//  earthlord
//
//  频道详情页面
//

import SwiftUI

struct ChannelDetailView: View {

    let channel: CommunicationChannel

    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteAlert = false

    private var currentUserId: UUID? {
        guard let idStr = authManager.currentUser?.id else { return nil }
        return UUID(uuidString: idStr)
    }

    private var isCreator: Bool {
        guard let userId = currentUserId else { return false }
        return channel.creatorId == userId
    }

    private var isSubscribed: Bool {
        communicationManager.isSubscribed(channelId: channel.id)
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {

                    // 信息卡片
                    VStack(spacing: 12) {
                        Image(systemName: channel.channelType.iconName)
                            .font(.system(size: 40))
                            .foregroundColor(ApocalypseTheme.primary)
                            .frame(width: 72, height: 72)
                            .background(ApocalypseTheme.primary.opacity(0.15))
                            .cornerRadius(16)

                        Text(channel.channelName)
                            .font(.title2).fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        HStack(spacing: 6) {
                            Image(systemName: channel.channelType.iconName)
                                .font(.caption2)
                            Text(channel.channelType.displayName)
                                .font(.caption).fontWeight(.medium)
                        }
                        .foregroundColor(ApocalypseTheme.primary)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(ApocalypseTheme.primary.opacity(0.15))
                        .cornerRadius(6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)

                    // 统计卡片
                    HStack(spacing: 0) {
                        statItem(value: "\(channel.memberCount)", label: "成员数", icon: "person.2.fill")
                        Divider()
                            .background(ApocalypseTheme.textSecondary.opacity(0.3))
                            .frame(height: 40)
                        statItem(value: "\(channel.maxMembers)", label: "上限", icon: "person.3.fill")
                        Divider()
                            .background(ApocalypseTheme.textSecondary.opacity(0.3))
                            .frame(height: 40)
                        statItem(value: formatDate(channel.createdAt), label: "创建日期", icon: "calendar")
                    }
                    .padding(.vertical, 16)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)

                    // 描述卡片
                    if !channel.description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("频道描述")
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Text(channel.description)
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                    }

                    // 频率信息
                    if !channel.frequency.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform")
                                .foregroundColor(ApocalypseTheme.primary)
                            Text("频率: \(channel.frequency)")
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            Spacer()
                        }
                        .padding(16)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                    }

                    Spacer().frame(height: 8)

                    // 进入聊天
                    if isSubscribed {
                        NavigationLink(destination: ChannelChatView(channel: channel).environmentObject(authManager)) {
                            HStack {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                Text("进入聊天")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(12)
                        }
                    }

                    // 操作按钮
                    if isSubscribed {
                        Button(action: {
                            guard let userId = currentUserId else { return }
                            Task {
                                await communicationManager.unsubscribeFromChannel(channelId: channel.id, userId: userId)
                            }
                        }) {
                            HStack {
                                Image(systemName: "bell.slash.fill")
                                Text("取消订阅")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(ApocalypseTheme.warning)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ApocalypseTheme.warning.opacity(0.15))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ApocalypseTheme.warning.opacity(0.3), lineWidth: 1)
                            )
                        }
                    } else {
                        Button(action: {
                            guard let userId = currentUserId else { return }
                            Task {
                                await communicationManager.subscribeToChannel(channelId: channel.id, userId: userId)
                            }
                        }) {
                            HStack {
                                Image(systemName: "bell.fill")
                                Text("订阅频道")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(12)
                        }
                    }

                    // 创建者删除按钮
                    if isCreator {
                        Button(action: { showDeleteAlert = true }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("删除频道")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(ApocalypseTheme.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ApocalypseTheme.danger.opacity(0.15))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ApocalypseTheme.danger.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("频道详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task {
                    await communicationManager.deleteChannel(channelId: channel.id)
                    dismiss()
                }
            }
        } message: {
            Text("确定要删除频道「\(channel.channelName)」吗？此操作不可撤销，所有订阅者将自动取消订阅。")
        }
    }

    // MARK: - 统计项

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.primary)
            Text(value)
                .font(.headline).fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 日期格式化

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}
