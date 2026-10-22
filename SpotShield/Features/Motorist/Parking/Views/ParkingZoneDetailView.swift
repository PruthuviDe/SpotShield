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
        _viewModel = State(initialValue: ParkingZoneDetailViewModel(zone: zone))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                Text(viewModel.zone.name)
                    .font(AppTypography.titleLarge)
                    .accessibilityAddTraits(.isHeader)
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        AppSectionHeader(title: "Parking rate")
                        Text("LKR \(viewModel.zone.hourlyRateLKR.formatted()) / hour")
                            .font(AppTypography.titleMedium)
                        Label("Maximum stay: \(viewModel.zone.maximumStayMinutes) minutes", systemImage: "hourglass")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        AppSectionHeader(title: "Opening hours")
                        Label("\(String(format: "%02d:00", viewModel.zone.openingHour))–\(String(format: "%02d:00", viewModel.zone.closingHour))", systemImage: "clock")
                            .font(AppTypography.bodyBold)
                        TimelineView(.periodic(from: .now, by: 60)) { clock in
                            let status = viewModel.openingStatus(at: clock.date)
                            AppStatusBadge(title: status, appearance: status == "Open now" ? .success : .neutral)
                        }
                        Text("Sri Lanka time")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                if case .signedIn(let profile) = appState.authState, profile.role == .motorist {
                    NavigationLink {
                        ParkingSetupView(zone: viewModel.zone, profile: profile)
                    } label: {
                        Label("Set Up Parking", systemImage: "parkingsign.circle")
                    }
                    .buttonStyle(AppButtonStyle())
                }
                Text("Rates and availability are checked again when you start parking.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Zone Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
