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
                    AppMessageView(
                        title: viewModel.errorMessage,
                        appearance: .error,
                        actionTitle: "Try Again",
                        action: { Task { await viewModel.loadObservations() } }
                    )
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

            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(AppSpacing.large)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.inline)
        .refreshOnAppearAndForeground { await viewModel.loadObservations() }
        .refreshable { await viewModel.loadObservations() }
    }

    private func observationCard(_ observation: WardenObservation) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(alignment: .top, spacing: AppSpacing.small) {
                    AppStatusBadge(
                        title: observation.reviewStatus.rawValue,
                        appearance: appearance(for: observation.reviewStatus)
                    )
                    Spacer(minLength: AppSpacing.small)
                    Text(observation.observedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.trailing)
                }

                Text(observation.licensePlate)
                    .font(AppTypography.titleMedium)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                Label(observation.zoneName, systemImage: "mappin.and.ellipse")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text("Parking check")
                        .font(AppTypography.captionBold)
                        .foregroundStyle(AppColors.textSecondary)

                    Text(observation.parkingStatus)
                        .font(AppTypography.bodyMedium)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AppSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.background, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))

                if hasReportDetails(observation) {
                    DisclosureGroup("Report details") {
                        VStack(alignment: .leading, spacing: AppSpacing.medium) {
                            if let notes = observation.notes, !notes.isEmpty {
                                recordDetail("Your notes", value: notes)
                            }
                            if let reason = observation.decisionReason, !reason.isEmpty {
                                AppMessageView(
                                    title: "Administrator decision",
                                    message: reason,
                                    appearance: observation.reviewStatus == .dismissed ? .success : .neutral
                                )
                            }
                            if let ticketId = observation.ticketId, !ticketId.isEmpty {
                                recordDetail("Ticket ID", value: ticketId)
                            }
                            if let paymentStatus = observation.ticketPaymentStatus, !paymentStatus.isEmpty {
                                recordDetail("Ticket payment", value: paymentStatus)
                            }
                        }
                        .padding(.top, AppSpacing.medium)
                    }
                    .font(AppTypography.bodyBold)
                    .tint(AppColors.textPrimary)
                }
            }
        }
    }

    private func hasReportDetails(_ observation: WardenObservation) -> Bool {
        (observation.notes?.isEmpty == false)
            || (observation.decisionReason?.isEmpty == false)
            || (observation.ticketId?.isEmpty == false)
            || (observation.ticketPaymentStatus?.isEmpty == false)
    }

    private func recordDetail(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(title)
                .font(AppTypography.captionBold)
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(AppTypography.bodySmall)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
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
