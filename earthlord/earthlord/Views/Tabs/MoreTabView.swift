import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                List {
                    Section {
                        NavigationLink(destination: NetworkDiagnosticsView()) {
                            HStack(spacing: 16) {
                                Image(systemName: "network.badge.shield.half.filled")
                                    .font(.title2)
                                    .foregroundColor(ApocalypseTheme.primary)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizedStringKey("网络诊断工具"))
                                        .font(.headline)
                                        .foregroundColor(ApocalypseTheme.textPrimary)

                                    Text(LocalizedStringKey("测试 Supabase 连接和诊断问题"))
                                        .font(.caption)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(ApocalypseTheme.cardBackground)

                        NavigationLink(destination: SupabaseTestView()) {
                            HStack(spacing: 16) {
                                Image(systemName: "network")
                                    .font(.title2)
                                    .foregroundColor(ApocalypseTheme.primary)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizedStringKey("Supabase 连接测试"))
                                        .font(.headline)
                                        .foregroundColor(ApocalypseTheme.textPrimary)

                                    Text(LocalizedStringKey("测试数据库连接状态"))
                                        .font(.caption)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(ApocalypseTheme.cardBackground)
                    } header: {
                        Text(LocalizedStringKey("开发工具"))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("更多")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
}

#Preview {
    MoreTabView()
}
