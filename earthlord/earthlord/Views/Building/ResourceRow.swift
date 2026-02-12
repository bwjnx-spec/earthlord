//
//  ResourceRow.swift
//  earthlord
//
//  单行资源需求显示
//

import SwiftUI

struct ResourceRow: View {

    let resourceId: String
    let required: Int
    let owned: Int

    private var isSufficient: Bool {
        owned >= required
    }

    private var resourceName: String {
        MockExplorationData.getItemDefinition(by: resourceId)?.name ?? resourceId
    }

    private var resourceIcon: String {
        guard let def = MockExplorationData.getItemDefinition(by: resourceId) else {
            return "questionmark.circle"
        }
        switch def.category {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.case.fill"
        case .material: return "hammer.fill"
        case .tool: return "wrench.fill"
        case .weapon: return "scope"
        case .clothing: return "tshirt.fill"
        case .misc: return "shippingbox.fill"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: resourceIcon)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 20)

            Text(resourceName)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            Text("\(owned)/\(required)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
        }
        .padding(.vertical, 4)
    }
}
