import SwiftUI
import Supabase

/// 测试视图：用于验证登录页面是否能正常显示
struct TestAuthView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("测试：登录页面")
                .font(.largeTitle)
                .padding()

            Text("如果你能看到这个界面，说明视图渲染正常")
                .foregroundColor(.secondary)

            Divider()

            // 尝试显示实际的 AuthView
            AuthView(authManager: AuthManager(supabase: supabaseClient))
        }
        .onAppear {
            print("🎯 TestAuthView 已显示")
        }
    }
}

#Preview {
    TestAuthView()
}
