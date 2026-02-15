//
//  ChannelCenterView.swift
//  earthlord
//
//  频道中心 - 我的频道 / 发现频道
//

import SwiftUI

struct ChannelCenterView: View {

    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var communicationManager = CommunicationManager.shared

    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var isFirstLoad = true

    private var currentUserId: UUID? {
        guard let idStr = authManager.currentUser?.id else { return nil }
        return UUID(uuidString: idStr)
    }

    private var filteredSubscribed: [CommunicationChannel] {
        if searchText.isEmpty { return communicationManager.subscribedChannels }
        return communicationManager.subscribedChannels.filter {
            $0.channelName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredAll: [CommunicationChannel] {
        if searchText.isEmpty { return communicationManager.channels }
        return communicationManager.channels.filter {
            $0.channelName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 搜索栏
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        TextField("搜索频道...", text: $searchText)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .padding(10)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Tab 切换
                    HStack(spacing: 0) {
                        tabButton(title: "我的频道", index: 0)
                        tabButton(title: "发现频道", index: 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // 内容区域
                    if communicationManager.isLoading && isFirstLoad {
                        Spacer()
                        ProgressView()
                            .tint(ApocalypseTheme.primary)
                        Text("加载中...")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .padding(.top, 8)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if selectedTab == 0 {
                                    myChannelsContent
                                } else {
                                    discoverContent
                                }
                            }
                            .padding(16)
                        }
                        .refreshable {
                            await refreshData()
                        }
                    }
                }

                // 悬浮创建按钮
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showCreateSheet = true }) {
                            Image(systemName: "plus")
                                .font(.title2).fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(ApocalypseTheme.primary)
                                .clipShape(Circle())
                                .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 8, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("频道中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showCreateSheet) {
                CreateChannelSheet()
                    .environmentObject(authManager)
            }
            .onAppear {
                if isFirstLoad {
                    Task {
                        await refreshData()
                        isFirstLoad = false
                    }
                }
            }
        }
    }

    // MARK: - 我的频道

    @ViewBuilder
    private var myChannelsContent: some View {
        if filteredSubscribed.isEmpty {
            emptyState(icon: "dot.radiowaves.left.and.right", title: "暂无订阅频道", subtitle: "去「发现频道」探索并订阅感兴趣的频道")
        } else {
            ForEach(filteredSubscribed) { channel in
                NavigationLink(destination: ChannelChatView(channel: channel).environmentObject(authManager)) {
                    channelCard(channel: channel, showSubscribeButton: false)
                }
            }
        }
    }

    // MARK: - 发现频道

    @ViewBuilder
    private var discoverContent: some View {
        if filteredAll.isEmpty {
            emptyState(icon: "magnifyingglass", title: "暂无可用频道", subtitle: "点击右下角 + 创建第一个频道")
        } else {
            ForEach(filteredAll) { channel in
                channelCard(channel: channel, showSubscribeButton: true)
            }
        }
    }

    // MARK: - 频道卡片

    private func channelCard(channel: CommunicationChannel, showSubscribeButton: Bool) -> some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: channel.channelType.iconName)
                .font(.title2)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 44, height: 44)
                .background(ApocalypseTheme.primary.opacity(0.15))
                .cornerRadius(10)

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.channelName)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(channel.channelType.displayName)
                        .font(.caption2).fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.primary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(ApocalypseTheme.primary.opacity(0.15))
                        .cornerRadius(4)

                    Label("\(channel.memberCount)", systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Spacer()

            // 订阅按钮
            if showSubscribeButton {
                let subscribed = communicationManager.isSubscribed(channelId: channel.id)
                Button(action: {
                    guard let userId = currentUserId else { return }
                    Task {
                        if subscribed {
                            await communicationManager.unsubscribeFromChannel(channelId: channel.id, userId: userId)
                        } else {
                            await communicationManager.subscribeToChannel(channelId: channel.id, userId: userId)
                        }
                    }
                }) {
                    Text(subscribed ? "已订阅" : "订阅")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(subscribed ? ApocalypseTheme.textSecondary : .white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(subscribed ? ApocalypseTheme.cardBackground : ApocalypseTheme.primary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(subscribed ? ApocalypseTheme.textSecondary.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Tab 按钮

    private func tabButton(title: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(selectedTab == index ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                Rectangle()
                    .fill(selectedTab == index ? ApocalypseTheme.primary : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 空状态

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text(title)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 刷新

    private func refreshData() async {
        guard let userId = currentUserId else { return }
        await communicationManager.loadPublicChannels()
        await communicationManager.loadSubscribedChannels(userId: userId)
    }
}
