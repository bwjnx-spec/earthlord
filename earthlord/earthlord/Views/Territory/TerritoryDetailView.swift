//
//  TerritoryDetailView.swift
//  earthlord
//
//  领地详情页 - 全屏地图 ZStack 布局
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - Properties

    let territory: Territory
    let onDelete: (() -> Void)?

    @StateObject private var territoryManager = TerritoryManager()
    @ObservedObject private var buildingManager = BuildingManager.shared
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var showInfoPanel = true
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var buildingsVersion = 0

    // Sheet management
    @State private var showBuildingBrowser = false
    @State private var pendingTemplate: BuildingTemplate? = nil
    @State private var selectedTemplateForPlacement: BuildingTemplate? = nil

    // Rename
    @State private var showRenameAlert = false
    @State private var renameText = ""

    // Demolish
    @State private var buildingToDemolish: UUID? = nil
    @State private var showDemolishAlert = false

    // MARK: - Computed Properties

    private var formattedCreatedAt: String {
        guard let createdAt = territory.createdAt else { return "未知" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: createdAt)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // Layer 1: Full-screen map
            TerritoryMapView(
                territory: territory,
                buildings: buildingManager.playerBuildings,
                templates: buildingManager.templates,
                buildingsVersion: buildingsVersion
            )
            .ignoresSafeArea()

            // Layer 2: Floating toolbar
            VStack {
                TerritoryToolbarView(
                    onClose: { dismiss() },
                    onRename: {
                        renameText = territory.name ?? ""
                        showRenameAlert = true
                    },
                    onBuild: { showBuildingBrowser = true },
                    onToggleInfo: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showInfoPanel.toggle()
                        }
                    }
                )
                .padding(.top, 50)

                Spacer()
            }

            // Layer 3: Bottom collapsible info panel
            if showInfoPanel {
                VStack {
                    Spacer()
                    infoPanel
                }
                .transition(.move(edge: .bottom))
            }
        }
        // Sheet: Building browser
        .sheet(isPresented: $showBuildingBrowser) {
            BuildingBrowserView(
                buildingManager: buildingManager,
                pendingTemplate: $pendingTemplate
            )
        }
        // Sheet: Building placement
        .sheet(item: $selectedTemplateForPlacement) { template in
            BuildingPlacementView(
                template: template,
                territory: territory,
                buildingManager: buildingManager
            )
        }
        // Delayed sheet transition: browser dismiss → placement open
        .onChange(of: showBuildingBrowser) { _, isShowing in
            if !isShowing && pendingTemplate != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    selectedTemplateForPlacement = pendingTemplate
                    pendingTemplate = nil
                }
            }
        }
        // Refresh buildings when placement sheet dismisses
        .onChange(of: selectedTemplateForPlacement) { _, newValue in
            if newValue == nil {
                refreshBuildings()
            }
        }
        // Delete alert
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                Task { await deleteTerritoryAction() }
            }
        } message: {
            Text("确定要删除这个领地吗？此操作无法撤销。")
        }
        // Rename alert
        .alert("重命名领地", isPresented: $showRenameAlert) {
            TextField("领地名称", text: $renameText)
            Button("取消", role: .cancel) { }
            Button("确定") {
                Task { await renameTerritory() }
            }
        } message: {
            Text("输入新的领地名称")
        }
        // Demolish alert
        .alert("确认拆除", isPresented: $showDemolishAlert) {
            Button("取消", role: .cancel) { }
            Button("拆除", role: .destructive) {
                Task { await demolishBuilding() }
            }
        } message: {
            Text("确定要拆除这个建筑吗？此操作无法撤销。")
        }
        // Load data
        .task {
            buildingManager.loadTemplates()
            if let uuid = UUID(uuidString: territory.id) {
                try? await buildingManager.fetchPlayerBuildings(territoryId: uuid)
                buildingsVersion += 1
            }
        }
    }

    // MARK: - Info Panel

    private var infoPanel: some View {
        VStack(spacing: 12) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            // Territory info card
            territoryInfoCard

            // Building list
            if !buildingManager.playerBuildings.isEmpty {
                buildingListSection
            }

            // Delete button
            deleteButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ApocalypseTheme.background.opacity(0.95))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var territoryInfoCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text(territory.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }

            TerritoryInfoRow(icon: "map", label: "面积", value: territory.formattedArea)
            TerritoryInfoRow(icon: "mappin.circle", label: "坐标点数", value: "\(territory.pointCount ?? 0) 个")
            TerritoryInfoRow(icon: "clock", label: "创建时间", value: formattedCreatedAt)
            TerritoryInfoRow(icon: "building.2", label: "建筑数量", value: "\(buildingManager.playerBuildings.count)")
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private var buildingListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("建筑列表")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            ForEach(buildingManager.playerBuildings) { building in
                TerritoryBuildingRow(
                    building: building,
                    template: buildingManager.getTemplate(by: building.templateId),
                    onUpgrade: {
                        Task {
                            try? await buildingManager.upgradeBuilding(buildingId: building.id)
                            buildingsVersion += 1
                        }
                    },
                    onDemolish: {
                        buildingToDemolish = building.id
                        showDemolishAlert = true
                    }
                )
            }
        }
    }

    private var deleteButton: some View {
        Button(action: { showDeleteAlert = true }) {
            HStack {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "trash")
                    Text("删除领地")
                }
            }
            .font(.system(size: 14, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(.white)
            .background(ApocalypseTheme.danger)
            .cornerRadius(10)
        }
        .disabled(isDeleting)
    }

    // MARK: - Actions

    private func deleteTerritoryAction() async {
        isDeleting = true
        let success = await territoryManager.deleteTerritory(territoryId: territory.id)
        isDeleting = false
        if success {
            dismiss()
            onDelete?()
        }
    }

    private func renameTerritory() async {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? await territoryManager.updateTerritoryName(territoryId: territory.id, newName: trimmed)
    }

    private func demolishBuilding() async {
        guard let buildingId = buildingToDemolish else { return }
        try? await buildingManager.demolishBuilding(buildingId: buildingId)
        buildingsVersion += 1
        buildingToDemolish = nil
    }

    private func refreshBuildings() {
        Task {
            if let uuid = UUID(uuidString: territory.id) {
                try? await buildingManager.fetchPlayerBuildings(territoryId: uuid)
                buildingsVersion += 1
            }
        }
    }
}

// MARK: - Info Row

struct TerritoryInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "test",
            userId: "test",
            name: "测试领地",
            path: [
                ["lat": 39.9, "lon": 116.4],
                ["lat": 39.91, "lon": 116.4],
                ["lat": 39.91, "lon": 116.41],
                ["lat": 39.9, "lon": 116.41]
            ],
            area: 10000,
            pointCount: 4,
            isActive: true,
            completedAt: nil,
            startedAt: nil,
            createdAt: Date()
        ),
        onDelete: nil
    )
}
