import SwiftUI

struct TerritoryTabView: View {
    var body: some View {
        PlaceholderView(
            icon: "flag.fill",
            title: LocalizedStringKey("领地"),
            subtitle: LocalizedStringKey("管理你的领地")
        )
    }
}

#Preview {
    TerritoryTabView()
}
