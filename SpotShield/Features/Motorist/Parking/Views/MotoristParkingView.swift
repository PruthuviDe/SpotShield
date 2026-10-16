//
//  MotoristParkingView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import SwiftUI

struct MotoristParkingView: View {
    @State private var viewModel = MotoristParkingViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.medium) {
                if viewModel.isLoading {
                    ProgressView("Loading parking zones...")
                }

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.statusOverstay)
                }

                if viewModel.zones.isEmpty,
                   !viewModel.isLoading,
                   viewModel.errorMessage.isEmpty {
                    Text("No parking zones to show yet.")
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                ForEach(viewModel.zones) { zone in
                    NavigationLink {
                        ParkingZoneDetailView(zone: zone)
                    } label: {
                        zoneCard(zone: zone)
                    }
                    .buttonStyle(.plain)
                }

                Text("Operating hours are shown in Sri Lanka time.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                Button("Refresh") {
                    Task {
                        await viewModel.loadZones()
                    }
                }
                .buttonStyle(.bordered)
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
        .task {
            await viewModel.loadZones()
        }
    }

    private func zoneCard(zone: ParkingZone) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(zone.name)
                .font(AppTypography.titleSmall)

            Text("LKR \(zone.hourlyRateLKR) per hour")
                .font(AppTypography.priceDisplay)

            Text(
                "Hours: \(zone.openingHour):00"
                + "–\(zone.closingHour):00"
            )
            .foregroundStyle(AppColors.textSecondary)

            Text("Maximum stay: \(zone.maximumStayMinutes) minutes")
                .foregroundStyle(AppColors.textSecondary)

            if zone.isActive {
                Text("Active zone — check parking hours")
                    .font(AppTypography.bodySmall)
            } else {
                Text("Currently unavailable")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.statusNeutral)
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
}
