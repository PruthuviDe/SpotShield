//
//  ParkingZonesView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import SwiftUI

struct ParkingZonesView: View {
    @State private var viewModel = ParkingZonesViewModel()

    @State private var showCreateZone = false
    @State private var selectedZone: ParkingZone?
    @State private var zoneForAction: ParkingZone?
    @State private var showZoneAction = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(
                    title: "Zone list",
                    subtitle: "Manage rates, hours and zone availability."
                )

                if !viewModel.errorMessage.isEmpty {
                    AppMessageView(
                        title: "Could not update parking zones",
                        message: viewModel.errorMessage,
                        appearance: .error,
                        actionTitle: "Try Again",
                        action: { Task { await viewModel.loadZones() } }
                    )
                }

                if !viewModel.successMessage.isEmpty {
                    AppMessageView(
                        title: viewModel.successMessage,
                        appearance: .success
                    )
                }

                if viewModel.isLoading && viewModel.zones.isEmpty {
                    AppLoadingView(title: "Loading parking zones…")
                } else if viewModel.zones.isEmpty,
                          viewModel.errorMessage.isEmpty {
                    AppEmptyStateView(
                        title: "No parking zones",
                        message: "Add a zone to set its price, hours and location.",
                        systemImage: "mappin.and.ellipse"
                    )
                } else {
                    ForEach(viewModel.zones) { zone in
                        zoneCard(zone: zone)
                    }
                }

            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.textPrimary)
        .navigationTitle("Parking Zones")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateZone = true
                } label: {
                    Label("Add Zone", systemImage: "plus")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .refreshOnAppearAndForeground { await viewModel.loadZones() }
        .refreshable {
            await viewModel.loadZones()
        }
        .sheet(
            isPresented: $showCreateZone,
            onDismiss: reloadZones
        ) {
            ParkingZoneFormView()
        }
        .sheet(
            item: $selectedZone,
            onDismiss: reloadZones
        ) { zone in
            ParkingZoneFormView(zone: zone)
        }
        .alert(
            "Confirm zone change",
            isPresented: $showZoneAction,
            presenting: zoneForAction
        ) { zone in
            if zone.isActive {
                Button("Deactivate Zone", role: .destructive) {
                    Task {
                        await viewModel.deactivateZone(zone: zone)
                    }
                }
            } else {
                ForEach(viewModel.activeAssignments(zoneId: zone.id)) { assignment in
                    Button {
                        Task {
                            await viewModel.publishZone(
                                zone: zone,
                                assignmentId: assignment.id
                            )
                        }
                    } label: {
                        Text(
                            actionTitle(for: zone)
                            + " with "
                            + viewModel.wardenName(userId: assignment.wardenUserId)
                        )
                    }
                }
            }

            Button("Cancel", role: .cancel) { }
        } message: { zone in
            if zone.isActive {
                Text(
                    "Make \(zone.name) inactive? Its details and history will be kept."
                )
            } else if zone.isPublished {
                Text(
                    "Choose an active Warden to activate \(zone.name). "
                    + "Hourly price: LKR \(zone.hourlyRateLKR)."
                )
            } else {
                Text(
                    "Choose an active Warden to publish and activate \(zone.name). "
                    + "Hourly price: LKR \(zone.hourlyRateLKR)."
                )
            }
        }
    }

    private func zoneCard(zone: ParkingZone) -> some View {
        let availableAssignments = viewModel.activeAssignments(zoneId: zone.id)

        return AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                HStack(alignment: .top, spacing: AppSpacing.small) {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text(zone.name)
                            .font(AppTypography.titleMedium)
                            .fixedSize(horizontal: false, vertical: true)
                        zoneStatusBadge(zone: zone)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        selectedZone = zone
                    } label: {
                        Image(systemName: "pencil")
                            .font(AppTypography.bodyBold)
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                            .background(AppColors.background, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit \(zone.name)")
                    .disabled(viewModel.isLoading)
                }

                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xSmall) {
                    Text("LKR \(zone.hourlyRateLKR.formatted())")
                        .font(AppTypography.priceDisplay)
                        .foregroundStyle(AppColors.accent)
                    Text("per hour")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textLight.opacity(0.8))
                }
                .padding(AppSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.buttonBackground, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))

                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    zoneDetail("Opening hours", value: "\(zone.openingHour):00–\(zone.closingHour):00", systemImage: "clock")
                    zoneDetail("Maximum stay", value: "\(zone.maximumStayMinutes) minutes", systemImage: "timer")
                }

                if zone.isActive {
                    AppButton(
                        title: "Deactivate Zone",
                        systemImage: "pause.circle",
                        appearance: .destructive,
                        isLoading: viewModel.isLoading
                    ) {
                        zoneForAction = zone
                        showZoneAction = true
                    }
                } else {
                    if availableAssignments.isEmpty {
                        Text("Assign an active Warden to this zone before publishing or activating it.")
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    AppButton(
                        title: actionTitle(for: zone),
                        systemImage: zone.isPublished ? "checkmark.circle" : "paperplane",
                        isLoading: viewModel.isLoading
                    ) {
                        zoneForAction = zone
                        showZoneAction = true
                    }
                    .disabled(viewModel.isLoading || availableAssignments.isEmpty)
                }
            }
        }
    }

    private func zoneStatusBadge(zone: ParkingZone) -> some View {
        if !zone.isPublished {
            AppStatusBadge(title: "Draft")
        } else if zone.isActive {
            AppStatusBadge(title: "Active", appearance: .success)
        } else {
            AppStatusBadge(title: "Inactive", appearance: .warning)
        }
    }

    private func actionTitle(for zone: ParkingZone) -> String {
        zone.isPublished ? "Activate Zone" : "Publish Zone"
    }

    private func zoneDetail(
        _ title: String,
        value: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .foregroundStyle(AppColors.statusValid)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text(value)
                    .font(AppTypography.bodyBold)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func reloadZones() {
        Task {
            await viewModel.loadZones()
        }
    }
}
