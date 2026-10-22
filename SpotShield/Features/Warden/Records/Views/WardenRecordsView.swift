//
//  WardenRecordsView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import SwiftUI

struct WardenRecordsView: View {
    @State private var viewModel = WardenRecordsViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.large) {
                AppSectionHeader(
                    title: "My observations",
                    subtitle: "Follow the review status and Administrator decision for each report."
                )

                if viewModel.isLoading && viewModel.observations.isEmpty {
                    AppLoadingView(title: "Loading observations…")
                }

                if !viewModel.errorMessage.isEmpty {
                    AppMessageView(title: viewModel.errorMessage, appearance: .error)
                }

                if viewModel.observations.isEmpty {
                    if !viewModel.isLoading && viewModel.errorMessage.isEmpty {
                        AppEmptyStateView(
                            title: "No observations yet",
                            message: "Observations you submit during patrol will appear here.",
                            systemImage: "doc.text.magnifyingglass"
                        )
                    }
                } else {
                    if viewModel.isLoading {
                        ProgressView("Refreshing observations…")
                            .font(AppTypography.bodySmall)
                    }

                    ForEach(viewModel.observations) { observation in
                        observationCard(observation)
                    }
                }

                AppButton(
                    title: "Refresh Records",
                    systemImage: "arrow.clockwise",
                    appearance: .secondary,
                    isLoading: viewModel.isLoading
                ) {
                    Task { await viewModel.loadObservations() }
                }
                .disabled(viewModel.isLoading)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(AppSpacing.large)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await viewModel.loadObservations() }
        }
        .refreshable { await viewModel.loadObservations() }
    }

    private func observationCard(_ observation: WardenObservation) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppStatusBadge(
                    title: observation.reviewStatus.rawValue,
                    appearance: appearance(for: observation.reviewStatus)
                )

                Text(observation.zoneName)
                    .font(AppTypography.titleMedium)
                    .fixedSize(horizontal: false, vertical: true)

                Label(observation.licensePlate, systemImage: "car")
                    .font(AppTypography.bodyBold)
                    .textSelection(.enabled)

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text("Parking check")
                        .font(AppTypography.captionBold)
                        .foregroundStyle(AppColors.textSecondary)

                    Text(observation.parkingStatus)
                        .font(AppTypography.bodySmall)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Label(
                    observation.observedAt.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "clock"
                )
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

                if let notes = observation.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text("Your notes")
                            .font(AppTypography.captionBold)
                            .foregroundStyle(AppColors.textSecondary)

                        Text(notes)
                            .font(AppTypography.bodySmall)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let reason = observation.decisionReason, !reason.isEmpty {
                    AppMessageView(
                        title: "Administrator decision",
                        message: reason,
                        appearance: observation.reviewStatus == .dismissed ? .success : .neutral
                    )
                }

                if let ticketId = observation.ticketId, !ticketId.isEmpty {
                    Text("Ticket ID: \(ticketId)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func appearance(for status: ObservationStatus) -> AppStatusAppearance {
        switch status {
        case .awaitingReview:
            .warning
        case .ticketIssued:
            .error
        case .dismissed:
            .success
        }
    }
}
