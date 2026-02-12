//
//  CategoryButton.swift
//  earthlord
//
//  建筑分类筛选按钮
//

import SwiftUI

struct CategoryButton: View {

    let category: BuildingCategory?
    let isSelected: Bool
    let action: () -> Void

    private var label: String {
        category?.displayName ?? "全部"
    }

    private var icon: String {
        category?.icon ?? "square.grid.2x2"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            .cornerRadius(20)
        }
    }
}
