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

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.medium) {
                if viewModel.isLoading {
                    ProgressView("Loading zones...")
                }

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.statusOverstay)
                }

                if viewModel.zones.isEmpty,
                   !viewModel.isLoading,
                   viewModel.errorMessage.isEmpty {
                    Text("No parking zones yet. Tap Add Zone to create one.")
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                ForEach(viewModel.zones) { zone in
                    zoneButton(zone: zone)
                }

                Button("Refresh") {
                    reloadZones()
                }
                .disabled(viewModel.isLoading)
            }
            .padding(AppSpacing.large)
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
    }

    private func zoneButton(zone: ParkingZone) -> some View {
        Button {
            selectedZone = zone
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(zone.name)
                    .font(AppTypography.titleSmall)

                Text("LKR \(zone.hourlyRateLKR) per hour")
                    .font(AppTypography.bodyBold)

                Text("Hours: \(zone.openingHour):00–\(zone.closingHour):00")

                Text("Maximum stay: \(zone.maximumStayMinutes) minutes")

                HStack {
                    Text(zone.isPublished ? "Published" : "Draft")
                        .font(AppTypography.captionBold)
                        .foregroundStyle(AppColors.textSecondary)

                    Spacer()

                    Label("Edit", systemImage: "pencil")
                        .font(AppTypography.bodySmall)
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
            .contentShape(
                RoundedRectangle(
                    cornerRadius: AppSpacing.radiusCard
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
    }

    private func reloadZones() {
        Task {
            await viewModel.loadZones()
        }
    }
}
