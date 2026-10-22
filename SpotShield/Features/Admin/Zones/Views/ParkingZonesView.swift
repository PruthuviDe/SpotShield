//
//  ParkingZonesView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import SwiftUI

struct ParkingZonesView: View {
    @State private var viewModel = ParkingZonesViewModel()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                        appearance: .error
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

                AppButton(
                    title: "Refresh",
                    systemImage: "arrow.clockwise",
                    appearance: .secondary,
                    isLoading: viewModel.isLoading
                ) {
                    reloadZones()
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
        .task {
            await viewModel.loadZones()
        }
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
        .confirmationDialog(
            "Confirm zone change",
            isPresented: $showZoneAction,
            titleVisibility: .visible,
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
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(alignment: .top, spacing: AppSpacing.small) {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Text(zone.name)
                                .font(AppTypography.titleSmall)

                            zoneStatusBadge(zone: zone)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(zone.name)
                            .font(AppTypography.titleSmall)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        zoneStatusBadge(zone: zone)
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Label("LKR \(zone.hourlyRateLKR) per hour", systemImage: "banknote")
                    Label(
                        "\(zone.openingHour):00–\(zone.closingHour):00",
                        systemImage: "clock"
                    )
                    Label(
                        "Maximum stay: \(zone.maximumStayMinutes) minutes",
                        systemImage: "timer"
                    )
                }
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)

                Button {
                    selectedZone = zone
                } label: {
                    managementButtonLabel(
                        title: "Edit zone",
                        systemImage: "pencil"
                    )
                }
                .buttonStyle(AppButtonStyle(appearance: .secondary))
                .disabled(viewModel.isLoading)

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

    private func managementButtonLabel(
        title: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: AppSpacing.small) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            Text(title)
        }
        .frame(maxWidth: .infinity, minHeight: AppSpacing.minTouchTarget)
        .contentShape(Capsule())
    }

    private func reloadZones() {
        Task {
            await viewModel.loadZones()
        }
    }
}
