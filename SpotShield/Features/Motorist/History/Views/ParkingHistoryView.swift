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
                NavigationLink {
                    MotoristTicketsView()
                } label: {
                    Label("Tickets", systemImage: "doc.text")
                }
                .buttonStyle(AppButtonStyle(appearance: .secondary))

                if viewModel.sessions.isEmpty {
                    if viewModel.isLoading {
                        AppLoadingView(title: "Loading parking history…")
                    } else if !viewModel.errorMessage.isEmpty {
                        AppMessageView(title: viewModel.errorMessage, appearance: .error)
                    } else {
                        AppEmptyStateView(title: "No parking history yet", message: "Your completed parking sessions will appear here.", systemImage: "clock.arrow.circlepath")
                    }
                } else {
                    if !viewModel.errorMessage.isEmpty {
                        AppMessageView(title: viewModel.errorMessage, appearance: .error)
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

                AppButton(title: "Refresh History", systemImage: "arrow.clockwise", appearance: .secondary) {
                    Task {
                        await viewModel.loadHistory()
                    }
                }
                .disabled(viewModel.isLoading)
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
        .task {
            await viewModel.loadHistory()
        }
        .refreshable {
            await viewModel.loadHistory()
        }
    }

    private func sessionCard(
        session: ParkingSession
    ) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppStatusBadge(title: "Completed")
                Text(session.zoneName)
                    .font(AppTypography.titleSmall)

                Text(session.licensePlate)
                    .font(AppTypography.bodyBold)

                Divider()

                Text("Started: \(formattedDate(session.startTime))")
                    .foregroundStyle(AppColors.textSecondary)

                Text("Paid until: \(formattedDate(session.paidUntil))")
                    .foregroundStyle(AppColors.textSecondary)

                if let endTime = session.endTime {
                    Text("Ended: \(formattedDate(endTime))")
                        .foregroundStyle(AppColors.textSecondary)
                }

                Text("Purchased time: \(session.durationMinutes) minutes")
                    .foregroundStyle(AppColors.textSecondary)

                Text("Paid: LKR \(session.totalPaidLKR.formatted())")
                    .font(AppTypography.bodyBold)

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
