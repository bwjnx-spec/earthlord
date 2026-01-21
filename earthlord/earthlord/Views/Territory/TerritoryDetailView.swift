//
//  TerritoryDetailView.swift
//  earthlord
//
//  Created on 2025/01/20.
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - Properties

    let territory: Territory
    let onDelete: (() -> Void)?

    @StateObject private var territoryManager = TerritoryManager()
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed Properties

    /// 地图区域
    private var mapRegion: MKCoordinateRegion {
        let coordinates = territory.toCoordinates()
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }

        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = (maxLat - minLat) * 1.5
        let spanLon = (maxLon - minLon) * 1.5

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: max(spanLat, 0.005), longitudeDelta: max(spanLon, 0.005))
        )
    }

    /// 格式化创建时间
    private var formattedCreatedAt: String {
        guard let createdAt = territory.createdAt else {
            return "未知"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: createdAt)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 地图预览
                    mapPreview

                    // 领地信息
                    territoryInfo

                    // 占位功能区
                    futureFeaturesSection

                    // 删除按钮
                    deleteButton
                }
                .padding()
            }
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    Task {
                        await deleteTerritoryAction()
                    }
                }
            } message: {
                Text("确定要删除这个领地吗？此操作无法撤销。")
            }
        }
    }

    // MARK: - Map Preview

    private var mapPreview: some View {
        Map(initialPosition: .region(mapRegion)) {
            // 显示领地边界
            MapPolygon(coordinates: territory.toCoordinates())
                .foregroundStyle(Color.blue.opacity(0.3))
                .stroke(Color.blue, lineWidth: 2)
        }
        .frame(height: 250)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    // MARK: - Territory Info

    private var territoryInfo: some View {
        VStack(spacing: 16) {
            Text("领地信息")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                TerritoryInfoRow(icon: "map", label: "面积", value: territory.formattedArea)
                TerritoryInfoRow(icon: "mappin.circle", label: "坐标点数", value: "\(territory.pointCount ?? 0) 个")
                TerritoryInfoRow(icon: "clock", label: "创建时间", value: formattedCreatedAt)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    // MARK: - Future Features Section

    private var futureFeaturesSection: some View {
        VStack(spacing: 16) {
            Text("即将推出")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                FeaturePlaceholder(icon: "pencil", title: "重命名领地", description: "自定义领地名称")
                FeaturePlaceholder(icon: "building.2", title: "建筑系统", description: "在领地上建造建筑")
                FeaturePlaceholder(icon: "arrow.left.arrow.right", title: "领地交易", description: "与其他玩家交易领地")
            }
        }
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(action: {
            showDeleteAlert = true
        }) {
            HStack {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "trash")
                    Text("删除领地")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
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
}

// MARK: - Info Row

struct TerritoryInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Feature Placeholder

struct FeaturePlaceholder: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.gray)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("敬请期待")
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray)
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .opacity(0.7)
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
