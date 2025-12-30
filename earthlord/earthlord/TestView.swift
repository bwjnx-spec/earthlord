//
//  TestView.swift
//  earthlord
//
//  Created by bwjnx-spec on 2025/12/23.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            // 淡蓝色背景
            Color.blue.opacity(0.2)
                .ignoresSafeArea()

            // 大标题
            Text("这里是分支宇宙的测试页")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

#Preview {
    TestView()
}
