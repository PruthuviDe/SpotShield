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
            LazyVStack(alignment: .leading, spacing: AppSpacing.large) {
                Picker("Cases", selection: $viewModel.showReviewed) {
                    Text("Pending").tag(false)
                    Text("Reviewed").tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isLoading || !viewModel.reviewingId.isEmpty)

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundStyle(AppColors.statusOverstay)
                }

                if !viewModel.successMessage.isEmpty {
                    Text(viewModel.successMessage)
                        .foregroundStyle(AppColors.statusValid)
                }

                if viewModel.isLoading && viewModel.observations.isEmpty {
                    ProgressView("Loading observations...")
                } else if viewModel.observations.isEmpty {
                    Text(viewModel.showReviewed ? "No reviewed observations yet." : "No observations are waiting for review.")
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    ForEach(viewModel.observations) { observation in
                        observationCard(observation)
                    }
                }

                Button("Refresh") {
                    Task { await viewModel.loadObservations() }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading || !viewModel.reviewingId.isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.large)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Review Observations")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: viewModel.showReviewed) { await viewModel.loadObservations() }
        .sheet(item: $viewModel.selectedObservation) { observation in
            decisionForm(observation)
        }
    }

    private func observationCard(_ observation: WardenObservation) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(observation.zoneName)
                .font(AppTypography.titleSmall)
            Text(observation.licensePlate)
                .font(AppTypography.bodyBold)
            Text(observation.parkingStatus)
                .foregroundStyle(observation.isViolation ? AppColors.statusOverstay : AppColors.statusValid)
            if let notes = observation.notes, !notes.isEmpty {
                Text(notes)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Text(observation.observedAt.formatted(date: .abbreviated, time: .shortened))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

            Text(observation.reviewStatus.rawValue)
                .font(AppTypography.bodyBold)
            if let reason = observation.decisionReason, !reason.isEmpty {
                Text("Decision: \(reason)")
            }
            if let ticketId = observation.ticketId, !ticketId.isEmpty {
                Text("Demo ticket: \(ticketId)")
                    .font(AppTypography.caption)
            }
            if observation.reviewStatus == .awaitingReview {
                Button("Dismiss Observation") {
                    viewModel.prepareReview(observation, issueTicket: false)
                }
                .buttonStyle(.bordered)
                if observation.isViolation {
                    Button("Review LKR 1,000 Demo Ticket", role: .destructive) {
                        viewModel.prepareReview(observation, issueTicket: true)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
    }

    private func decisionForm(_ observation: WardenObservation) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Text(observation.licensePlate).font(AppTypography.titleSmall)
                    Text(observation.zoneName)
                    Text("Observed: \(observation.parkingStatus)")
                    if viewModel.isCheckingReview {
                        ProgressView("Checking current parking and zone policy...")
                    }
                    if let details = viewModel.reviewDetails {
                        Text("Current: \(details.check.parkingStatus)")
                        Text("Checked at \(details.check.checkedAt.formatted(date: .omitted, time: .standard))")
                            .font(AppTypography.caption)
                        if !details.issueBlockedReason.isEmpty {
                            Text(details.issueBlockedReason).foregroundStyle(AppColors.statusOverstay)
                        }
                        if viewModel.issueTicket && !details.recipientKnown {
                            Text("No registered owner was found. This ticket will remain due without a wallet charge.")
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    if !viewModel.reviewErrorMessage.isEmpty {
                        Text(viewModel.reviewErrorMessage).foregroundStyle(AppColors.statusOverstay)
                    }
                    TextField("Decision reason", text: $viewModel.decisionReason, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                    Text("Demo decision only. No real fine or payment is involved.")
                        .font(AppTypography.caption)
                    Button(viewModel.issueTicket ? "Confirm LKR 1,000 Demo Ticket" : "Confirm Dismissal") {
                        Task { await viewModel.confirmDecision() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canConfirmDecision)
                    Button("Refresh current check") {
                        Task { await viewModel.loadReview(id: observation.id) }
                    }
                    .disabled(viewModel.isCheckingReview || !viewModel.reviewingId.isEmpty)
                }
                .padding(AppSpacing.large)
            }
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

}
