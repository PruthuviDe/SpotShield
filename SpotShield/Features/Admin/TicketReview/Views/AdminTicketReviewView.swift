//
//  AdminTicketReviewView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import SwiftUI

struct AdminTicketReviewView: View {
    @State private var viewModel = AdminTicketReviewViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(
                    title: "Observation review",
                    subtitle: "Review Warden reports and record your decision."
                )

                AppCard {
                    Picker("Observations", selection: $viewModel.showReviewed) {
                        Text("Awaiting review").tag(false)
                        Text("Reviewed").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .disabled(viewModel.isLoading || !viewModel.reviewingId.isEmpty)
                }

                if !viewModel.errorMessage.isEmpty {
                    AppMessageView(
                        title: "Could not load observations",
                        message: viewModel.errorMessage,
                        appearance: .error
                    )
                }

                if !viewModel.successMessage.isEmpty {
                    AppMessageView(
                        title: viewModel.successMessage,
                        appearance: .success
                    )
                }

                if viewModel.isLoading && viewModel.observations.isEmpty {
                    AppLoadingView(title: "Loading observations…")
                } else if viewModel.observations.isEmpty {
                    AppEmptyStateView(
                        title: viewModel.showReviewed
                            ? "No reviewed observations"
                            : "No observations waiting",
                        message: viewModel.showReviewed
                            ? "Administrator decisions will appear here."
                            : "New Warden reports will appear here for review.",
                        systemImage: "doc.text.magnifyingglass"
                    )
                } else {
                    ForEach(viewModel.observations) { observation in
                        observationCard(observation)
                    }

                    if viewModel.observations.count == 50 {
                        Text("Showing the latest 50 observations.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                AppButton(
                    title: "Refresh",
                    systemImage: "arrow.clockwise",
                    appearance: .secondary,
                    isLoading: viewModel.isLoading
                ) {
                    Task { await viewModel.loadObservations() }
                }
                .disabled(viewModel.isLoading || !viewModel.reviewingId.isEmpty)
            }
            .frame(maxWidth: 700, alignment: .leading)
            .padding(AppSpacing.large)
            .frame(maxWidth: .infinity)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.textPrimary)
        .navigationTitle("Review Observations")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: viewModel.showReviewed) {
            await viewModel.loadObservations()
        }
        .refreshable {
            await viewModel.loadObservations()
        }
        .sheet(item: $viewModel.selectedObservation) { observation in
            decisionForm(observation)
        }
    }

    private func observationCard(_ observation: WardenObservation) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(alignment: .top, spacing: AppSpacing.small) {
                    Text(observation.zoneName)
                        .font(AppTypography.titleSmall)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    AppStatusBadge(
                        title: observation.reviewStatus.rawValue,
                        appearance: reviewAppearance(observation.reviewStatus)
                    )
                }

                Text(observation.licensePlate)
                    .font(AppTypography.titleMedium)
                    .textSelection(.enabled)

                AppStatusBadge(
                    title: observation.parkingStatus,
                    appearance: observation.isViolation ? .error : .success
                )

                if let notes = observation.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Label(
                    "Observed \(observation.observedAt.formatted(date: .abbreviated, time: .shortened))",
                    systemImage: "clock"
                )
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

                if let reason = observation.decisionReason, !reason.isEmpty {
                    LabeledContent("Decision reason", value: reason)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                }

                if let ticketId = observation.ticketId, !ticketId.isEmpty {
                    LabeledContent("Ticket ID", value: ticketId)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .textSelection(.enabled)
                }

                if viewModel.showReviewed,
                   let paymentStatus = observation.ticketPaymentStatus,
                   !paymentStatus.isEmpty {
                    AppStatusBadge(
                        title: "Payment: \(paymentStatus)",
                        appearance: .neutral
                    )
                }

                if observation.reviewStatus == .awaitingReview {
                    AppButton(
                        title: "Dismiss Observation",
                        systemImage: "xmark.circle",
                        appearance: .secondary
                    ) {
                        viewModel.prepareReview(observation, issueTicket: false)
                    }
                    .disabled(!viewModel.reviewingId.isEmpty)

                    if observation.isViolation {
                        AppButton(
                            title: "Issue LKR 1,000 Ticket",
                            systemImage: "doc.badge.plus"
                        ) {
                            viewModel.prepareReview(observation, issueTicket: true)
                        }
                        .disabled(!viewModel.reviewingId.isEmpty)
                    }
                }
            }
        }
    }

    private func decisionForm(_ observation: WardenObservation) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    AppSectionHeader(
                        title: viewModel.issueTicket ? "Issue ticket" : "Dismiss observation",
                        subtitle: "Review the current parking check and enter a reason."
                    )

                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Text(observation.licensePlate)
                                .font(AppTypography.titleMedium)
                                .textSelection(.enabled)

                            Text(observation.zoneName)
                                .font(AppTypography.bodyBold)

                            Text("Warden check: \(observation.parkingStatus)")
                                .font(AppTypography.bodySmall)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }

                    if viewModel.isCheckingReview {
                        AppLoadingView(title: "Checking current parking…")
                    }

                    if let details = viewModel.reviewDetails {
                        AppCard {
                            VStack(alignment: .leading, spacing: AppSpacing.small) {
                                AppSectionHeader(title: "Current parking check")
                                AppStatusBadge(
                                    title: details.check.parkingStatus,
                                    appearance: details.check.hasValidParking ? .success : .error
                                )
                                Text(
                                    "Checked \(details.check.checkedAt.formatted(date: .abbreviated, time: .shortened))"
                                )
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)

                                if !details.issueBlockedReason.isEmpty {
                                    AppMessageView(
                                        title: "Ticket cannot be issued",
                                        message: details.issueBlockedReason,
                                        appearance: .error
                                    )
                                }

                                if viewModel.issueTicket && !details.recipientKnown {
                                    AppMessageView(
                                        title: "No account is linked to this plate",
                                        message: "The ticket will be recorded without a wallet charge."
                                    )
                                }
                            }
                        }
                    }

                    if !viewModel.reviewErrorMessage.isEmpty {
                        AppMessageView(
                            title: "Could not save the decision",
                            message: viewModel.reviewErrorMessage,
                            appearance: .error
                        )
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Text("Decision reason")
                                .font(AppTypography.bodyBold)

                            TextField(
                                "Enter the reason",
                                text: $viewModel.decisionReason,
                                axis: .vertical
                            )
                            .lineLimit(2...4)
                            .textFieldStyle(AppTextFieldStyle())
                            .accessibilityLabel("Decision reason")

                            Text("Up to 200 characters")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }

                    AppButton(
                        title: decisionButtonTitle,
                        systemImage: viewModel.issueTicket ? "doc.badge.plus" : "xmark.circle",
                        isLoading: !viewModel.reviewingId.isEmpty
                    ) {
                        Task { await viewModel.confirmDecision() }
                    }
                    .disabled(!viewModel.canConfirmDecision)

                    AppButton(
                        title: "Refresh current check",
                        systemImage: "arrow.clockwise",
                        appearance: .secondary,
                        isLoading: viewModel.isCheckingReview
                    ) {
                        Task { await viewModel.loadReview(id: observation.id) }
                    }
                    .disabled(viewModel.isCheckingReview || !viewModel.reviewingId.isEmpty)
                }
                .padding(AppSpacing.large)
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Confirm Decision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.selectedObservation = nil }
                        .disabled(!viewModel.reviewingId.isEmpty)
                }
            }
            .interactiveDismissDisabled(!viewModel.reviewingId.isEmpty)
            .task { await viewModel.loadReview(id: observation.id) }
        }
    }

    private var decisionButtonTitle: String {
        viewModel.issueTicket ? "Confirm Ticket Issue" : "Confirm Dismissal"
    }

    private func reviewAppearance(_ status: ObservationStatus) -> AppStatusAppearance {
        switch status {
        case .awaitingReview: .warning
        case .ticketIssued: .neutral
        case .dismissed: .success
        }
    }
}
