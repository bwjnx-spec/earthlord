//
//  BuildingBrowserView.swift
//  earthlord
//
//  建筑模板浏览器
//

import SwiftUI

struct BuildingBrowserView: View {

    @ObservedObject var buildingManager: BuildingManager
    @Binding var pendingTemplate: BuildingTemplate?
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: BuildingCategory? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var filteredTemplates: [BuildingTemplate] {
        if let category = selectedCategory {
            return buildingManager.templates.filter { $0.category == category }
        }
        return buildingManager.templates
    }

    private var playerResources: [String: Int] {
        buildingManager.getCurrentResources()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Category filter bar
                    categoryFilterBar
                        .padding(.top, 8)

                    // Building grid
                    if filteredTemplates.isEmpty {
                        Spacer()
                        Text("该分类下暂无建筑")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(filteredTemplates) { template in
                                    BuildingCard(
                                        template: template,
                                        playerResources: playerResources,
                                        onTap: {
                                            pendingTemplate = template
                                            dismiss()
                                        }
                                    )
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("建筑蓝图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryButton(category: nil, isSelected: selectedCategory == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = nil
                    }
                }

                ForEach(BuildingCategory.allCases, id: \.self) { category in
                    CategoryButton(category: category, isSelected: selectedCategory == category) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
