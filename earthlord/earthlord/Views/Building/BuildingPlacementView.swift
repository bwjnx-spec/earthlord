//
//  BuildingPlacementView.swift
//  earthlord
//
//  建造确认页 = 地图选点 + 资源确认 + 执行建造
//

import SwiftUI
import CoreLocation

struct BuildingPlacementView: View {

    let template: BuildingTemplate
    let territory: Territory
    @ObservedObject var buildingManager: BuildingManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLocation: CLLocationCoordinate2D? = nil
    @State private var isLocationValid: Bool = false
    @State private var isBuilding = false
    @State private var errorMessage: String? = nil
    @State private var showSuccessAlert = false

    private var playerResources: [String: Int] {
        buildingManager.getCurrentResources()
    }

    private var hasEnoughResources: Bool {
        for (resourceId, amount) in template.requiredResources {
            if (playerResources[resourceId] ?? 0) < amount {
                return false
            }
        }
        return true
    }

    private var canBuild: Bool {
        selectedLocation != nil && isLocationValid && hasEnoughResources && !isBuilding
    }

    private var formattedBuildTime: String {
        let seconds = template.buildTimeSeconds
        if seconds >= 3600 {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return mins > 0 ? "\(hours)小时\(mins)分钟" : "\(hours)小时"
        } else if seconds >= 60 {
            return "\(seconds / 60)分钟"
        }
        return "\(seconds)秒"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Map picker (~45% height)
                    mapSection

                    // Resource confirmation + build button
                    ScrollView {
                        VStack(spacing: 16) {
                            // Location status
                            locationStatusSection

                            // Resource requirements
                            resourceSection

                            // Build time
                            buildTimeSection

                            // Error message
                            if let error = errorMessage {
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(ApocalypseTheme.danger)
                                    .padding(.horizontal)
                            }

                            // Build button
                            buildButton
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("建造 \(template.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("建造成功", isPresented: $showSuccessAlert) {
                Button("确定") { dismiss() }
            } message: {
                Text("\(template.name) 已开始建造，预计 \(formattedBuildTime) 完成")
            }
        }
    }

    // MARK: - Sections

    private var mapSection: some View {
        BuildingLocationPickerView(
            territory: territory,
            existingBuildings: buildingManager.playerBuildings,
            templates: buildingManager.templates,
            selectedLocation: $selectedLocation,
            isLocationValid: $isLocationValid
        )
        .frame(height: UIScreen.main.bounds.height * 0.38)
        .clipped()
    }

    private var locationStatusSection: some View {
        HStack(spacing: 8) {
            Image(systemName: selectedLocation == nil ? "location.slash" : (isLocationValid ? "checkmark.circle.fill" : "xmark.circle.fill"))
                .foregroundColor(selectedLocation == nil ? ApocalypseTheme.textMuted : (isLocationValid ? ApocalypseTheme.success : ApocalypseTheme.danger))

            if selectedLocation == nil {
                Text("点击地图选择建造位置")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            } else if isLocationValid {
                Text("位置有效")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.success)
            } else {
                Text("位置无效：必须在领地范围内")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.danger)
            }

            Spacer()
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    private var resourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("所需资源")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            ForEach(Array(template.requiredResources.keys.sorted()), id: \.self) { resourceId in
                ResourceRow(
                    resourceId: resourceId,
                    required: template.requiredResources[resourceId] ?? 0,
                    owned: playerResources[resourceId] ?? 0
                )
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    private var buildTimeSection: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text("建造时间")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
            Text(formattedBuildTime)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    private var buildButton: some View {
        Button(action: startBuild) {
            HStack {
                if isBuilding {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "hammer.fill")
                    Text("开始建造")
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(.white)
            .background(canBuild ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            .cornerRadius(12)
        }
        .disabled(!canBuild)
    }

    // MARK: - Actions

    private func startBuild() {
        guard let location = selectedLocation else { return }

        guard let territoryUUID = UUID(uuidString: territory.id) else {
            errorMessage = "领地 ID 格式错误"
            return
        }

        isBuilding = true
        errorMessage = nil

        Task {
            do {
                try await buildingManager.startConstruction(
                    templateId: template.templateId,
                    territoryId: territoryUUID,
                    location: location
                )
                showSuccessAlert = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isBuilding = false
        }
    }
}
