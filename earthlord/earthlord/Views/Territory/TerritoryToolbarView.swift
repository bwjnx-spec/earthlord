//
//  TerritoryToolbarView.swift
//  earthlord
//
//  领地详情页悬浮工具栏
//

import SwiftUI

struct TerritoryToolbarView: View {

    let onClose: () -> Void
    let onRename: () -> Void
    let onBuild: () -> Void
    let onToggleInfo: () -> Void

    var body: some View {
        HStack {
            // Left: close button
            toolbarButton(icon: "xmark", action: onClose)

            Spacer()

            // Right: rename + build + info
            HStack(spacing: 12) {
                toolbarButton(icon: "pencil", action: onRename)
                toolbarButton(icon: "building.2.fill", action: onBuild)
                toolbarButton(icon: "info.circle", action: onToggleInfo)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func toolbarButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
    }
}
