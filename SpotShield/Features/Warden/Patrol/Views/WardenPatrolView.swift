//
//  WardenPatrolView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import SwiftUI

struct WardenPatrolView: View {
    @State private var viewModel = WardenPatrolViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if viewModel.isLoading && viewModel.zones.isEmpty {
                    ProgressView("Loading assigned zones...")
                }

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundStyle(AppColors.statusOverstay)
                }

                if !viewModel.successMessage.isEmpty {
                    Text(viewModel.successMessage)
                        .foregroundStyle(AppColors.statusValid)
                }

                if let pending = viewModel.pendingSubmission {
                    Text("Submission not yet confirmed: \(pending.licensePlate)")
                    Button("Retry pending observation") {
                        Task { await viewModel.retrySubmission() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading)
                }

                if viewModel.zones.isEmpty && !viewModel.isLoading && viewModel.errorMessage.isEmpty {
                    Text("No active parking zones are assigned to you.")
                        .foregroundStyle(AppColors.textSecondary)
                } else if !viewModel.zones.isEmpty {
                    patrolForm
                }

                Button("Refresh") {
                    Task { await viewModel.loadZones() }
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
        .navigationTitle("Warden Patrol")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadZones() }
    }

    private var patrolForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Picker("Assigned zone", selection: $viewModel.selectedZoneId) {
                Text("Choose a zone").tag("")
                ForEach(viewModel.zones) { zone in
                    Text(zone.name).tag(zone.id)
                }
            }

            TextField("License plate", text: $viewModel.licensePlate)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(AppSpacing.medium)
                .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard))

            Toggle("I have confirmed this plate and zone", isOn: $viewModel.isConfirmed)

            Button(viewModel.isLoading ? "Checking..." : "Check Plate") {
                Task { await viewModel.checkPlate() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading || !viewModel.isConfirmed || viewModel.selectedZoneId.isEmpty || viewModel.licensePlate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let checkResult = viewModel.checkResult {
                Text(checkResult.status.rawValue)
                    .font(AppTypography.bodyBold)
                    .foregroundStyle(checkResult.status == .expiring ? AppColors.statusExpiring : AppColors.textPrimary)

                Text(checkResult.parkingStatus)
                    .foregroundStyle(checkResult.hasValidParking ? AppColors.statusValid : AppColors.statusOverstay)

                Text("Checked at \(checkResult.checkedAt.formatted(date: .omitted, time: .standard))")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                if checkResult.status.canReport {
                    TextField("Observation notes (optional)", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(AppSpacing.medium)
                        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard))

                    Button(viewModel.isLoading ? "Submitting..." : "Submit Observation") {
                        Task { await viewModel.submitObservation() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading || !viewModel.isConfirmed)
                }
            }
        }
        .disabled(viewModel.isLoading || viewModel.pendingSubmission != nil)
    }
}
