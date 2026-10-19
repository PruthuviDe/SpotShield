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
                if viewModel.isLoading {
                    ProgressView("Loading parking history...")
                } else if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundStyle(AppColors.statusOverstay)
                } else if viewModel.sessions.isEmpty {
                    Text("No ended parking sessions yet.")
                        .foregroundStyle(AppColors.textSecondary)
                } else {
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

                Button("Refresh") {
                    Task {
                        await viewModel.loadHistory()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.large)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Parking History")
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
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(session.zoneName)
                .font(AppTypography.titleSmall)

            Text(session.licensePlate)
                .font(AppTypography.bodyBold)

            Text("Ended")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

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

            Text("Demo payment. No real money was charged.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(
            AppColors.card,
            in: RoundedRectangle(
                cornerRadius: AppSpacing.radiusCard
            )
        )
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: "Asia/Colombo")

        return formatter.string(from: date)
    }
}
