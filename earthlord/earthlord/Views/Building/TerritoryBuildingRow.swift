//
//  TerritoryBuildingRow.swift
//  earthlord
//
//  领地建筑列表行
//

import SwiftUI

struct TerritoryBuildingRow: View {

    let building: PlayerBuilding
    let template: BuildingTemplate?
    let onUpgrade: () -> Void
    let onDemolish: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Left: progress ring + icon
            ZStack {
                if building.status == .constructing {
                    Circle()
                        .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 3)
                        .frame(width: 44, height: 44)

                    Circle()
                        .trim(from: 0, to: building.buildProgress)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                } else {
                    Circle()
                        .fill(ApocalypseTheme.success.opacity(0.2))
                        .frame(width: 44, height: 44)
                }

                Image(systemName: template?.icon ?? "building.2")
                    .font(.system(size: 18))
                    .foregroundColor(building.status == .constructing ? .orange : ApocalypseTheme.success)
            }

            // Center: name + level + status
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(building.buildingName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("Lv.\(building.level)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                if building.status == .constructing {
                    Text("建造中 \(building.formattedRemainingTime)")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                } else {
                    Text(building.status.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(building.status.color)
                }
            }

            Spacer()

            // Right: context menu
            Menu {
                if building.status == .active {
                    Button(action: onUpgrade) {
                        Label("升级", systemImage: "arrow.up.circle")
                    }
                }
                Button(role: .destructive, action: onDemolish) {
                    Label("拆除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}
