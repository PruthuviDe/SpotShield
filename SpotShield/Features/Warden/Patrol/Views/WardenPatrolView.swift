//
//  WardenPatrolView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import SwiftUI

struct WardenPatrolView: View {
    @State private var viewModel = WardenPatrolViewModel()
    @State private var isShowingPlateScanner = false

    private var canCheckPlate: Bool {
        viewModel.isConfirmed
            && !viewModel.selectedZoneId.isEmpty
            && !viewModel.licensePlate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isLoading
            && viewModel.pendingSubmission == nil
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            AppSectionHeader(
                title: "Patrol",
                subtitle: "Check a vehicle in your assigned zone and report a concern for review."
            )

            if !viewModel.errorMessage.isEmpty {
                AppMessageView(
                    title: viewModel.errorMessage,
                    appearance: .error,
                    actionTitle: viewModel.zones.isEmpty ? "Try Again" : nil,
                    action: viewModel.zones.isEmpty
                        ? { Task { await viewModel.loadZones() } }
                        : nil
                )
            }

            if !viewModel.successMessage.isEmpty {
                AppMessageView(title: viewModel.successMessage, appearance: .success)
            }

            if let pendingSubmission = viewModel.pendingSubmission {
                pendingSubmissionCard(pendingSubmission)
            } else if viewModel.zones.isEmpty {
                if viewModel.isLoading {
                    AppLoadingView(title: "Loading assigned zones…")
                } else if viewModel.errorMessage.isEmpty {
                    AppEmptyStateView(
                        title: "No assigned zones",
                        message: "You don’t have an active patrol zone at the moment.",
                        systemImage: "mappin.slash"
                    )
                }
            } else {
                patrolForm
            }

        }
        .frame(maxWidth: 720, alignment: .leading)
        .padding(AppSpacing.large)
        .frame(maxWidth: .infinity)
    }

    var body: some View {
        ScrollView {
            bodyContent
        }
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Patrol")
        .navigationBarTitleDisplayMode(.inline)
        .refreshOnAppearAndForeground { await viewModel.loadZones() }
        .refreshable { await viewModel.loadZones() }
        .sheet(isPresented: $isShowingPlateScanner) {
            NavigationStack {
                WardenPlateScanning { scannedPlate in
                    viewModel.licensePlate = scannedPlate
                }
            }
            .tint(AppColors.textPrimary)
        }
    }

    private var patrolForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            zoneSelectionCard

            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    AppSectionHeader(
                        title: "Vehicle plate",
                        subtitle: "Scan the full plate, then check that each character is correct."
                    )

                    scanPlateButton

                    HStack(spacing: AppSpacing.small) {
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(height: 1)
                        Text("OR ENTER MANUALLY")
                            .font(AppTypography.captionBold)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize()
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(height: 1)
                    }
                    .accessibilityHidden(true)

                    TextField("License plate", text: $viewModel.licensePlate)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textFieldStyle(AppTextFieldStyle())
                        .accessibilityLabel("Vehicle license plate")

                    Toggle(isOn: $viewModel.isConfirmed) {
                        Text("I have confirmed the plate and selected zone.")
                            .font(AppTypography.bodySmall)
                    }
                    .tint(AppColors.statusValid)
                    .disabled(viewModel.isLoading)

                    AppButton(
                        title: viewModel.isLoading ? "Checking Plate…" : "Check Plate",
                        systemImage: "checkmark.shield",
                        isLoading: viewModel.isLoading
                    ) {
                        Task { await viewModel.checkPlate() }
                    }
                    .disabled(!canCheckPlate)
                }
            }

            if let checkResult = viewModel.checkResult {
                checkResultCard(checkResult)
            }
        }
    }

    private var zoneSelectionCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(spacing: AppSpacing.medium) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 48, height: 48)
                        .background(AppColors.buttonBackground, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text("Patrol zone")
                            .font(AppTypography.titleSmall)
                        Text("Choose where you checked the vehicle")
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Picker("Assigned zone", selection: $viewModel.selectedZoneId) {
                    ForEach(viewModel.zones) { zone in
                        Text(zone.name).tag(zone.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, minHeight: AppSpacing.minTouchTarget, alignment: .leading)
                .padding(.horizontal, AppSpacing.medium)
                .background(AppColors.background, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
                .disabled(viewModel.isLoading)
            }
        }
    }

    private var scanPlateButton: some View {
        Button {
            isShowingPlateScanner = true
        } label: {
            HStack(spacing: AppSpacing.medium) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 48, height: 48)
                    .background(AppColors.buttonBackground, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text("Scan license plate")
                        .font(AppTypography.bodyBold)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Use the camera to read the plate")
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
            .overlay {
                RoundedRectangle(cornerRadius: AppSpacing.radiusButton)
                    .strokeBorder(AppColors.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        .accessibilityHint("Opens the camera to scan a license plate")
    }

    private func pendingSubmissionCard(_ submission: ObservationSubmission) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppStatusBadge(title: "Submission needs confirmation", appearance: .warning)

                AppSectionHeader(
                    title: "Check the saved result",
                    subtitle: "The status of the observation for \(submission.licensePlate) is not confirmed yet. Retry to check it safely."
                )

                AppButton(
                    title: viewModel.isLoading ? "Checking Submission…" : "Retry Submission",
                    systemImage: "arrow.clockwise",
                    isLoading: viewModel.isLoading
                ) {
                    Task { await viewModel.retrySubmission() }
                }
                .disabled(viewModel.isLoading)
            }
        }
    }

    private func checkResultCard(_ result: PlateCheckResult) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(alignment: .top, spacing: AppSpacing.small) {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        AppSectionHeader(title: "Plate check")
                        AppStatusBadge(
                            title: result.status.rawValue,
                            appearance: appearance(for: result.status)
                        )
                    }
                    Spacer(minLength: AppSpacing.small)
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(appearance(for: result.status).foreground)
                        .accessibilityHidden(true)
                }
                Text(result.parkingStatus)
                    .font(AppTypography.titleSmall)
                    .fixedSize(horizontal: false, vertical: true)
                Label("Checked at \(result.checkedAt.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                if result.status.canReport {
                    Divider()
                        .overlay(AppColors.border)

                    AppSectionHeader(
                        title: "Submit an observation",
                        subtitle: "An Administrator reviews observations before making a ticket decision."
                    )

                    TextField("Observation notes (optional)", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(AppTextFieldStyle())

                    AppButton(
                        title: viewModel.isLoading ? "Submitting Observation…" : "Submit Observation",
                        systemImage: "doc.badge.plus",
                        isLoading: viewModel.isLoading
                    ) {
                        Task { await viewModel.submitObservation() }
                    }
                    .disabled(viewModel.isLoading || !viewModel.isConfirmed)
                }
            }
        }
    }

    private func appearance(for status: ParkingStatus) -> AppStatusAppearance {
        switch status {
        case .valid:
            .success
        case .expiring:
            .warning
        case .overstay:
            .error
        case .noCheckIn:
            .warning
        case .cannotCheck, .outsideHours, .inactiveZone:
            .neutral
        }
    }
}
