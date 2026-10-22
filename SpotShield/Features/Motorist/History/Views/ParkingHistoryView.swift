//
//  ParkingHistoryView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import SwiftUI

struct ParkingHistoryView: View {
    @State private var viewModel: ParkingHistoryViewModel

    init(profile: UserProfile) {
        _viewModel = State(
            initialValue: ParkingHistoryViewModel(profile: profile)
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: AppSpacing.large
            ) {
                AppSectionHeader(title: "Parking history", subtitle: "Your completed parking stays.")
                NavigationLink {
                    MotoristTicketsView()
                } label: {
                    HStack(spacing: AppSpacing.medium) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 48, height: 48)
                            .background(AppColors.buttonBackground, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
                        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                            Text("Tickets")
                                .font(AppTypography.bodyBold)
                                .foregroundStyle(AppColors.textPrimary)
                            Text("Review issued tickets and payments")
                                .font(AppTypography.bodySmall)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer(minLength: AppSpacing.small)
                        Image(systemName: "chevron.right")
                            .font(AppTypography.captionBold)
                            .foregroundStyle(AppColors.textSecondary)
                            .accessibilityHidden(true)
                    }
                    .padding(AppSpacing.medium)
                    .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens your parking tickets")

                if viewModel.sessions.isEmpty {
                    if viewModel.isLoading {
                        AppLoadingView(title: "Loading parking history…")
                    } else if !viewModel.errorMessage.isEmpty {
                        AppMessageView(
                            title: viewModel.errorMessage,
                            appearance: .error,
                            actionTitle: "Try Again",
                            action: { Task { await viewModel.loadHistory() } }
                        )
                    } else {
                        AppEmptyStateView(title: "No parking history yet", message: "Your completed parking sessions will appear here.", systemImage: "clock.arrow.circlepath")
                    }
                } else {
                    if !viewModel.errorMessage.isEmpty {
                        AppMessageView(
                            title: viewModel.errorMessage,
                            appearance: .error,
                            actionTitle: "Try Again",
                            action: { Task { await viewModel.loadHistory() } }
                        )
                    }

                    Text(
                        "Showing up to 50 ended sessions. "
                        + "Times are shown in Sri Lanka time."
                    )
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                    ForEach(viewModel.sessions) { session in
                        sessionCard(session: session)
                    }
                }

            }
            .padding(AppSpacing.large)
            .padding(.bottom, AppSpacing.xxLarge * 2)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .refreshOnAppearAndForeground { await viewModel.loadHistory() }
        .refreshable {
            await viewModel.loadHistory()
        }
    }

    private func sessionCard(
        session: ParkingSession
    ) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                HStack(alignment: .top, spacing: AppSpacing.small) {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        AppStatusBadge(title: "Completed", appearance: .neutral)
                        Text(session.zoneName)
                            .font(AppTypography.titleMedium)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: AppSpacing.small)
                    Text("LKR \(session.totalPaidLKR.formatted())")
                        .font(AppTypography.bodyBold)
                        .foregroundStyle(AppColors.statusValid)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Label(session.licensePlate, systemImage: "car")
                    .font(AppTypography.bodyBold)
                Divider()
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    historyDetail("Started", value: formattedDate(session.startTime))
                    historyDetail("Paid until", value: formattedDate(session.paidUntil))
                    if let endTime = session.endTime {
                        historyDetail("Ended", value: formattedDate(endTime))
                    }
                    historyDetail("Time purchased", value: "\(session.durationMinutes) minutes")
                }
            }
        }
    }

    private func historyDetail(_ title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).foregroundStyle(AppColors.textSecondary)
                Spacer(minLength: AppSpacing.small)
                Text(value).font(AppTypography.bodySmall.weight(.semibold))
            }
            VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text(value)
                    .font(AppTypography.bodySmall.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: "Asia/Colombo")

        return formatter.string(from: date)
    }
}
