//
//  TradeRatingSheetView.swift
//  earthlord
//
//  交易评价弹窗
//  支持星级评分和评语输入
//

import SwiftUI

struct TradeRatingSheetView: View {

    // MARK: - 属性

    let history: TradeHistory

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var tradeManager = TradeManager.shared

    // MARK: - 状态

    @State private var selectedRating: Int = 0
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    private var ratingLabel: String {
        switch selectedRating {
        case 1: return "非常差"
        case 2: return "较差"
        case 3: return "一般"
        case 4: return "良好"
        case 5: return "非常好"
        default: return "点击评分"
        }
    }

    private var canSubmit: Bool {
        selectedRating >= 1 && selectedRating <= 5 && !isSubmitting
    }

    // MARK: - 视图主体

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer()

                    // 标题
                    Text("为这次交易评分")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 星星评分
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedRating = star
                                }
                            } label: {
                                Image(systemName: star <= selectedRating ? "star.fill" : "star")
                                    .font(.system(size: 36))
                                    .foregroundColor(star <= selectedRating ? ApocalypseTheme.warning : ApocalypseTheme.textMuted)
                            }
                        }
                    }

                    // 评分文字
                    Text(ratingLabel)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(selectedRating > 0 ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)

                    // 评语输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("评语（可选）")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        TextField("写下你的评价...", text: $comment, axis: .vertical)
                            .lineLimit(3...6)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .padding(12)
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 16)

                    Spacer()

                    // 提交按钮
                    Button {
                        submitRating()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text("提交评价")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSubmit ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        .cornerRadius(12)
                    }
                    .disabled(!canSubmit)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("交易评价")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("提示", isPresented: $showAlert) {
                Button("确定") {
                    if alertMessage?.contains("成功") == true {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    // MARK: - 提交评价

    private func submitRating() {
        isSubmitting = true
        Task {
            do {
                try await tradeManager.rateTrade(
                    historyId: history.id,
                    rating: selectedRating,
                    comment: comment.isEmpty ? nil : comment
                )
                alertMessage = "评价成功！"
                showAlert = true
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
            isSubmitting = false
        }
    }
}
