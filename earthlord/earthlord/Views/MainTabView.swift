import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            MapTabView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("地图")
                }
                .tag(0)

            TerritoryTabView()
                .tabItem {
                    Image(systemName: "flag.fill")
                    Text("领地")
                }
                .tag(1)

            POIListView()
                .tabItem {
                    Image(systemName: "scope")
                    Text("探索")
                }
                .tag(2)

            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("个人")
                }
                .tag(3)

            TestMenuView()
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver.fill")
                    Text("测试")
                }
                .tag(4)
        }
        .tint(ApocalypseTheme.primary)
        .refreshOnLanguageChange()
    }
}

#Preview {
    MainTabView()
}
