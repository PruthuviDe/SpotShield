//
//  ParkingZoneDetailView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import SwiftUI

struct ParkingZoneDetailView: View {
    @State private var viewModel: ParkingZoneDetailViewModel
    @Environment(AppState.self) private var appState

    init(zone: ParkingZone) {
        _viewModel = State(
            initialValue: ParkingZoneDetailViewModel(zone: zone)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                zoneDetails
                openingDetails

                Text(
                    "These details were loaded from the parking zone list. "
                    + "Go back and tap Refresh to load any changes."
                )
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
            }
            .padding(AppSpacing.large)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Zone Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var zoneDetails: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(viewModel.zone.name)
                .font(AppTypography.titleMedium)

            Text("LKR \(viewModel.zone.hourlyRateLKR) per hour")
                .font(AppTypography.priceDisplay)

            Text(
                "Maximum stay: "
                + "\(viewModel.zone.maximumStayMinutes) minutes"
            )
            .foregroundStyle(AppColors.textSecondary)
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

    private var openingDetails: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Opening hours")
                .font(AppTypography.titleSmall)

            Text(
                "\(viewModel.zone.openingHour):00"
                + "–\(viewModel.zone.closingHour):00"
            )

            Text("Hours are shown in Sri Lanka time.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

            TimelineView(.periodic(from: .now, by: 1)) { clock in
                Text(viewModel.openingStatus(at: clock.date))
                    .font(AppTypography.bodyBold)
            }

            if case .signedIn(let profile) = appState.authState {
                if profile.role == .motorist {
                    NavigationLink {
                        ParkingSetupView(
                            zone: viewModel.zone,
                            profile: profile
                        )
                    } label: {
                        Text("Check My Vehicle")
                            .font(AppTypography.bodyBold)
                            .frame(maxWidth: .infinity)
                            .padding(AppSpacing.medium)
                            .foregroundStyle(AppColors.textOnAccent)
                            .background(
                                AppColors.accent,
                                in: RoundedRectangle(
                                    cornerRadius: AppSpacing.radiusButton
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
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
