//
//  MotoristParkingView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import SwiftUI

struct MotoristParkingView: View {
    let profile: UserProfile
    @State private var viewModel = MotoristParkingViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.large) {
                AppSectionHeader(title: "Choose your zone", subtitle: "Check the rate and opening hours before you park.")
                if viewModel.isLoading {
                    AppLoadingView(title: "Loading parking zones…")
                } else if !viewModel.errorMessage.isEmpty {
                    AppMessageView(
                        title: viewModel.errorMessage,
                        appearance: .error,
                        actionTitle: "Try Again",
                        action: { Task { await viewModel.loadZones() } }
                    )
                }
                if !viewModel.zones.isEmpty {
                    NavigationLink {
                        ParkingZoneMapView(zones: viewModel.zones, userId: profile.id)
                    } label: {
                        HStack(spacing: AppSpacing.medium) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(AppColors.accent)
                                .frame(width: 52, height: 52)
                                .background(AppColors.buttonBackground, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
                            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                                Text("Explore on the map")
                                    .font(AppTypography.titleSmall)
                                    .foregroundStyle(AppColors.textPrimary)
                                Text("Browse parking zones on the map")
                                    .font(AppTypography.bodySmall)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            Spacer(minLength: AppSpacing.small)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.captionBold)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(AppSpacing.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the parking zone map")
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
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Parking Zones")
        .navigationBarTitleDisplayMode(.inline)
        .refreshOnAppearAndForeground { await viewModel.loadZones() }
        .refreshable { await viewModel.loadZones() }
    }

    private func zoneCard(_ zone: ParkingZone) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                HStack(alignment: .top, spacing: AppSpacing.medium) {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        AppStatusBadge(title: zone.isActive ? "Zone active" : "Unavailable", appearance: zone.isActive ? .success : .neutral)
                        Text(zone.name)
                            .font(AppTypography.titleMedium)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: AppSpacing.small)
                    Image(systemName: "chevron.right")
                        .font(AppTypography.captionBold)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.top, AppSpacing.small)
                        .accessibilityHidden(true)
                }
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xSmall) {
                    Text("LKR \(zone.hourlyRateLKR.formatted())")
                        .font(AppTypography.priceDisplay)
                    Text("per hour")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Divider()
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.large) {
                        zoneDetail("\(String(format: "%02d:00", zone.openingHour))–\(String(format: "%02d:00", zone.closingHour))", systemImage: "clock")
                        zoneDetail("Up to \(zone.maximumStayMinutes) min", systemImage: "hourglass")
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        zoneDetail("\(String(format: "%02d:00", zone.openingHour))–\(String(format: "%02d:00", zone.closingHour))", systemImage: "clock")
                        zoneDetail("Up to \(zone.maximumStayMinutes) min", systemImage: "hourglass")
                    }
                }
            }
            .foregroundStyle(AppColors.textPrimary)
        }
    }

    private func zoneDetail(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(AppTypography.bodySmall)
            .foregroundStyle(AppColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
