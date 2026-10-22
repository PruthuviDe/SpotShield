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
            LazyVStack(alignment: .leading, spacing: AppSpacing.large) {
                AppSectionHeader(title: "Choose your zone", subtitle: "Check the rate and opening hours before you park.")
                if viewModel.isLoading {
                    AppLoadingView(title: "Loading parking zones…")
                } else if !viewModel.errorMessage.isEmpty {
                    AppMessageView(title: viewModel.errorMessage, appearance: .error)
                }
                if !viewModel.zones.isEmpty {
                    NavigationLink {
                        ParkingZoneMapView(zones: viewModel.zones)
                    } label: {
                        Label("View Parking Map", systemImage: "map")
                    }
                    .buttonStyle(AppButtonStyle())
                } else if !viewModel.isLoading, viewModel.errorMessage.isEmpty {
                    AppEmptyStateView(title: "No zones available", message: "Check again later for available parking zones.", systemImage: "map")
                }
                ForEach(viewModel.zones) { zone in
                    NavigationLink {
                        ParkingZoneDetailView(zone: zone)
                    } label: {
                        zoneCard(zone)
                    }
                    .buttonStyle(.plain)
                }
                Text("All parking hours are shown in Sri Lanka time.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                AppButton(title: "Refresh Zones", systemImage: "arrow.clockwise", appearance: .secondary) {
                    Task { await viewModel.loadZones() }
                }
                .disabled(viewModel.isLoading)
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Parking Zones")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadZones() }
        .refreshable { await viewModel.loadZones() }
    }

    private func zoneCard(_ zone: ParkingZone) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppStatusBadge(title: zone.isActive ? "Check opening hours" : "Unavailable", appearance: .neutral)
                HStack(alignment: .firstTextBaseline) {
                    Text(zone.name).font(AppTypography.titleMedium)
                    Spacer(minLength: AppSpacing.small)
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                }
                Text("LKR \(zone.hourlyRateLKR.formatted()) / hour")
                    .font(AppTypography.priceDisplay)
                Label("\(String(format: "%02d:00", zone.openingHour))–\(String(format: "%02d:00", zone.closingHour))", systemImage: "clock")
                Label("Up to \(zone.maximumStayMinutes) minutes", systemImage: "hourglass")
            }
            .foregroundStyle(AppColors.textPrimary)
        }
    }
}
