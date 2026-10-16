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
            VStack(spacing: AppSpacing.medium) {
                if viewModel.isLoading {
                    ProgressView("Please wait...")
                }

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.statusOverstay)
                }

                if !viewModel.successMessage.isEmpty {
                    Text(viewModel.successMessage)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.statusValid)
                }

                if viewModel.zones.isEmpty,
                   !viewModel.isLoading,
                   viewModel.errorMessage.isEmpty {
                    Text("No parking zones yet. Tap Add Zone to create one.")
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                ForEach(viewModel.zones) { zone in
                    zoneCard(zone: zone)
                }

                Button("Refresh") {
                    reloadZones()
                }
            }
            .padding(AppSpacing.large)
            .disabled(viewModel.isLoading)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.textPrimary)
        .navigationTitle("Parking Zones")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isLoading)
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
                ForEach(
                    viewModel.activeAssignments(zoneId: zone.id)
                ) { assignment in
                    Button {
                        Task {
                            await viewModel.publishZone(
                                zone: zone,
                                assignmentId: assignment.id
                            )
                        }
                    } label: {
                        Text(
                            "Confirm with "
                            + viewModel.wardenName(
                                userId: assignment.wardenUserId
                            )
                        )
                    }
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: { zone in
            if zone.isActive {
                Text(
                    "Make \(zone.name) inactive? "
                    + "Its saved details and history will be kept."
                )
            } else {
                Text(
                    "Choose a Warden to make \(zone.name) active. "
                    + "Hourly price: LKR \(zone.hourlyRateLKR)."
                )
            }
        }
    }

    private func zoneCard(zone: ParkingZone) -> some View {
        let availableAssignments = viewModel.activeAssignments(
            zoneId: zone.id
        )

        return VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(zone.name)
                .font(AppTypography.titleSmall)

            Text("LKR \(zone.hourlyRateLKR) per hour")
                .font(AppTypography.bodyBold)

            Text("Hours: \(zone.openingHour):00–\(zone.closingHour):00")

            Text("Maximum stay: \(zone.maximumStayMinutes) minutes")

            HStack {
                Text(zoneStatus(zone: zone))
                    .font(AppTypography.captionBold)
                    .foregroundStyle(
                        zone.isActive
                            ? AppColors.statusValid
                            : AppColors.statusNeutral
                    )

                Spacer()

                Button("Edit") {
                    selectedZone = zone
                }
                .buttonStyle(.bordered)
                .frame(minHeight: AppSpacing.minTouchTarget)
            }

            if zone.isActive {
                Button("Deactivate Zone", role: .destructive) {
                    zoneForAction = zone
                    showZoneAction = true
                }
                .buttonStyle(.bordered)
                .tint(AppColors.statusOverstay)
                .frame(minHeight: AppSpacing.minTouchTarget)
            } else {
                if availableAssignments.isEmpty {
                    Text(
                        "Assign an active Warden to this zone "
                        + "before publishing or activating it."
                    )
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                }

                Button {
                    zoneForAction = zone
                    showZoneAction = true
                } label: {
                    Text(
                        zone.isPublished
                            ? "Activate Zone"
                            : "Publish Zone"
                    )
                    .font(AppTypography.bodyBold)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: AppSpacing.minTouchTarget
                    )
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(AppColors.buttonBackground)
                .foregroundStyle(AppColors.accent)
                .disabled(availableAssignments.isEmpty)
            }
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

    private func zoneStatus(zone: ParkingZone) -> String {
        if !zone.isPublished {
            return "Draft"
        }

        if zone.isActive {
            return "Published · Active"
        }

        return "Published · Inactive"
    }

    private func reloadZones() {
        Task {
            await viewModel.loadZones()
        }
    }
}
