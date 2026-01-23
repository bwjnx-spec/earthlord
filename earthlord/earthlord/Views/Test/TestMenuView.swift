//
//  TestMenuView.swift
//  earthlord
//
//  测试菜单视图 - 提供各种测试功能的入口
//  注意：不套 NavigationStack，由外部控制
//

import SwiftUI

struct TestMenuView: View {
    @State private var selectedTest: TestOption? = nil

    enum TestOption: String, CaseIterable, Identifiable {
        case territory = "领地测试"
        case supabase = "Supabase 测试"
        case network = "网络诊断"
        case backpack = "背包测试"
        case poi = "POI 列表"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .territory: return "map.circle.fill"
            case .supabase: return "server.rack"
            case .network: return "network"
            case .backpack: return "backpack.fill"
            case .poi: return "scope"
            }
        }

        var description: String {
            switch self {
            case .territory: return "测试圈地功能、闭环检测、速度检测"
            case .supabase: return "测试 Supabase 数据库连接和操作"
            case .network: return "诊断网络连接状态"
            case .backpack: return "测试背包管理、物品筛选和操作"
            case .poi: return "测试 POI 地点列表和详情"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(TestOption.allCases) { option in
                        NavigationLink(value: option) {
                            HStack(spacing: 16) {
                                // 图标
                                Image(systemName: option.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(ApocalypseTheme.primary)
                                    .frame(width: 40)

                                // 文字
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.rawValue)
                                        .font(.headline)
                                        .foregroundColor(ApocalypseTheme.textPrimary)

                                    Text(option.description)
                                        .font(.caption)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Text("测试功能")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(ApocalypseTheme.warning)
                        Text("这是开发测试菜单，正式发布时会移除")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .navigationTitle("测试中心")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: TestOption.self) { option in
                destinationView(for: option)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for option: TestOption) -> some View {
        switch option {
        case .territory:
            TerritoryTestView()
        case .supabase:
            SupabaseTestView()
        case .network:
            NetworkDiagnosticsView()
        case .backpack:
            BackpackView()
        case .poi:
            POIListView()
        }
    }
}

#Preview {
    TestMenuView()
}
