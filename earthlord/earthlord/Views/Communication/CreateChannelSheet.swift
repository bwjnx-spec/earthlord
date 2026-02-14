//
//  CreateChannelSheet.swift
//  earthlord
//
//  创建频道页面
//

import SwiftUI

struct CreateChannelSheet: View {

    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var channelName = ""
    @State private var channelDescription = ""
    @State private var selectedType: ChannelType = .publicChannel
    @State private var isCreating = false
    @State private var showSuccessAlert = false

    private var currentUserId: UUID? {
        guard let idStr = authManager.currentUser?.id else { return nil }
        return UUID(uuidString: idStr)
    }

    private var isValid: Bool {
        channelName.count >= 2 && channelName.count <= 50
    }

    private let selectableTypes: [ChannelType] = [.publicChannel, .privateChannel]

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // 频道类型选择
                        VStack(alignment: .leading, spacing: 10) {
                            Text("频道类型")
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            HStack(spacing: 12) {
                                ForEach(selectableTypes, id: \.self) { type in
                                    Button(action: { selectedType = type }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: type.iconName)
                                                .font(.caption)
                                            Text(type.displayName)
                                                .font(.subheadline).fontWeight(.medium)
                                        }
                                        .foregroundColor(selectedType == type ? .white : ApocalypseTheme.textSecondary)
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                        .background(selectedType == type ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedType == type ? Color.clear : ApocalypseTheme.textSecondary.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                }
                                Spacer()
                            }
                        }
                        .padding(16)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)

                        // 频道名称
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("频道名称")
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                                Spacer()
                                Text("\(channelName.count)/50")
                                    .font(.caption)
                                    .foregroundColor(channelName.count > 50 ? ApocalypseTheme.danger : ApocalypseTheme.textSecondary)
                            }

                            TextField("输入频道名称（2-50字）", text: $channelName)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .padding(12)
                                .background(ApocalypseTheme.background)
                                .cornerRadius(8)
                                .onChange(of: channelName) { _, newValue in
                                    if newValue.count > 50 {
                                        channelName = String(newValue.prefix(50))
                                    }
                                }
                        }
                        .padding(16)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)

                        // 频道描述
                        VStack(alignment: .leading, spacing: 10) {
                            Text("频道描述（可选）")
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            TextEditor(text: $channelDescription)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 80)
                                .padding(8)
                                .background(ApocalypseTheme.background)
                                .cornerRadius(8)
                        }
                        .padding(16)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)

                        // 创建按钮
                        Button(action: { Task { await createChannel() } }) {
                            HStack {
                                if isCreating {
                                    ProgressView()
                                        .tint(.white)
                                        .padding(.trailing, 4)
                                }
                                Text(isCreating ? "创建中..." : "创建频道")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isValid && !isCreating ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3))
                            .cornerRadius(12)
                        }
                        .disabled(!isValid || isCreating)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("创建频道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("创建成功", isPresented: $showSuccessAlert) {
                Button("好的") { dismiss() }
            } message: {
                Text("频道「\(channelName)」已创建，你已自动订阅该频道。")
            }
        }
    }

    private func createChannel() async {
        guard let userId = currentUserId, isValid else { return }
        isCreating = true
        let success = await communicationManager.createChannel(
            creatorId: userId,
            name: channelName,
            type: selectedType,
            description: channelDescription
        )
        isCreating = false
        if success {
            showSuccessAlert = true
        }
    }
}
