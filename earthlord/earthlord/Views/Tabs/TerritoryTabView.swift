//
//  TerritoryTabView.swift
//  earthlord
//
//  Created on 2025/01/19.
//

import SwiftUI

struct TerritoryTabView: View {

    // MARK: - Properties

    @StateObject private var territoryManager = TerritoryManager()
    @State private var myTerritories: [Territory] = []
    @State private var selectedTerritory: Territory?
    @State private var isLoading = false
    @State private var errorMessage: String?

    // MARK: - Computed Properties

    /// 总领地数量
    private var territoryCount: Int {
        myTerritories.count
    }

    /// 总面积（平方米）
    private var totalArea: Double {
        myTerritories.reduce(0) { $0 + $1.area }
    }

    /// 格式化的总面积
    private var formattedTotalArea: String {
        if totalArea >= 1_000_000 {
            return String(format: "%.2f km²", totalArea / 1_000_000)
        } else {
            return String(format: "%.0f m²", totalArea)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("加载中...")
                } else if myTerritories.isEmpty {
                    emptyStateView
                } else {
                    territoryListView
                }
            }
            .navigationTitle("我的领地")
            .refreshable {
                await loadTerritories()
            }
            .sheet(item: $selectedTerritory) { territory in
                TerritoryDetailView(
                    territory: territory,
                    onDelete: {
                        selectedTerritory = nil
                        Task {
                            await loadTerritories()
                        }
                    }
                )
            }
            .task {
                await loadTerritories()
            }
            .onReceive(NotificationCenter.default.publisher(for: .territoryUpdated)) { _ in
                Task { await loadTerritories() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .territoryDeleted)) { _ in
                selectedTerritory = nil
                Task { await loadTerritories() }
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("还没有领地")
                .font(.title2)
                .fontWeight(.semibold)

            Text("去地图 Tab 圈地吧")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Territory List View

    private var territoryListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 统计头部
                statisticsHeader

                // 领地列表
                LazyVStack(spacing: 12) {
                    ForEach(myTerritories) { territory in
                        TerritoryCard(territory: territory)
                            .onTapGesture {
                                selectedTerritory = territory
                            }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Statistics Header

    private var statisticsHeader: some View {
        HStack(spacing: 20) {
            // 领地数量
            VStack(spacing: 8) {
                Text("\(territoryCount)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.blue)

                Text("领地数量")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)

            // 总面积
            VStack(spacing: 8) {
                Text(formattedTotalArea)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.green)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("总面积")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - Methods

    private func loadTerritories() async {
        isLoading = true
        errorMessage = nil

        do {
            myTerritories = try await territoryManager.loadMyTerritories()
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
            print("❌ 加载领地失败: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Territory Card

struct TerritoryCard: View {
    let territory: Territory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：名称和面积
            HStack {
                Text(territory.displayName)
                    .font(.headline)

                Spacer()

                Text(territory.formattedArea)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }

            // 底部：详细信息
            HStack(spacing: 16) {
                Label("\(territory.pointCount ?? 0) 个点", systemImage: "mappin.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let createdAt = territory.createdAt {
                    Label(formatDate(createdAt), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    TerritoryTabView()
}
