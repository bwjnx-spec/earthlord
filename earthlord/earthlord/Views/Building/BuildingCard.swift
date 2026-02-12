//
//  BuildingCard.swift
//  earthlord
//
//  建筑模板网格卡片
//

import SwiftUI

struct BuildingCard: View {

    let template: BuildingTemplate
    let playerResources: [String: Int]
    let onTap: () -> Void

    private var hasEnoughResources: Bool {
        for (resourceId, amount) in template.requiredResources {
            if (playerResources[resourceId] ?? 0) < amount {
                return false
            }
        }
        return true
    }

    private var formattedBuildTime: String {
        let seconds = template.buildTimeSeconds
        if seconds >= 3600 {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return mins > 0 ? "\(hours)h\(mins)m" : "\(hours)h"
        } else if seconds >= 60 {
            return "\(seconds / 60)m"
        }
        return "\(seconds)s"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Icon + Tier badge
                HStack {
                    Image(systemName: template.icon)
                        .font(.system(size: 28))
                        .foregroundColor(ApocalypseTheme.primary)

                    Spacer()

                    Text("T\(template.tier)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tierColor)
                        .cornerRadius(4)
                }

                // Name
                Text(template.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                // Description
                Text(template.description)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineLimit(2)
                    .frame(minHeight: 30, alignment: .topLeading)

                // Build time + resource indicator
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(formattedBuildTime)
                        .font(.system(size: 11))

                    Spacer()

                    Circle()
                        .fill(hasEnoughResources ? ApocalypseTheme.success : ApocalypseTheme.danger)
                        .frame(width: 8, height: 8)
                }
                .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var tierColor: Color {
        switch template.tier {
        case 1: return .gray
        case 2: return .blue
        case 3: return .purple
        default: return .orange
        }
    }
}
