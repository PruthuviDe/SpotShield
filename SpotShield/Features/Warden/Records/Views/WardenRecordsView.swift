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
                if viewModel.isLoading && viewModel.observations.isEmpty {
                    ProgressView("Loading observations...")
                } else if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundStyle(AppColors.statusOverstay)
                } else if viewModel.observations.isEmpty {
                    Text("You have not submitted any observations yet.")
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
                .disabled(viewModel.isLoading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.large)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("My Observations")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadObservations() }
    }

    private func observationCard(_ observation: WardenObservation) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(observation.zoneName)
                .font(AppTypography.titleSmall)
            Text(observation.licensePlate)
                .font(AppTypography.bodyBold)
            Text(observation.parkingStatus)
                .foregroundStyle(observation.isViolation ? AppColors.statusOverstay : AppColors.statusValid)
            Text(observation.reviewStatus.rawValue)
                .font(AppTypography.bodyBold)
            Text(observation.observedAt.formatted(date: .abbreviated, time: .shortened))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
            if let notes = observation.notes, !notes.isEmpty {
                Text(notes)
                    .foregroundStyle(AppColors.textSecondary)
            }
            if let reason = observation.decisionReason, !reason.isEmpty {
                Text("Decision: \(reason)")
                    .foregroundStyle(AppColors.textSecondary)
            }
            if let ticketId = observation.ticketId, !ticketId.isEmpty {
                Text("Demo ticket issued")
                    .foregroundStyle(AppColors.statusOverstay)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
    }
}
