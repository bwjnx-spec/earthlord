//
//  ContentView.swift
//  earthlord
//
//  Created by 何小宝 on 2025/12/23.
//

import SwiftUI
import Combine

/// 主内容视图（已登录状态）
struct ContentView: View {
    /// 从环境中获取认证管理器
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        MainTabView()
            .environmentObject(authManager)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager(supabase: supabaseClient))
}
