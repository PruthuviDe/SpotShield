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
                    VStack(alignment: .leading, spacing: AppSpacing.large) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                                Text("Parking rate")
                                    .font(AppTypography.bodySmall)
                                    .foregroundStyle(AppColors.textLight.opacity(0.8))
                                Text("LKR \(viewModel.zone.hourlyRateLKR.formatted())")
                                    .font(AppTypography.timerDisplay)
                                    .foregroundStyle(AppColors.accent)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: AppSpacing.small)
                            Image(systemName: "parkingsign.circle.fill")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(AppColors.accent)
                                .accessibilityHidden(true)
                        }
                        Divider().overlay(AppColors.textLight.opacity(0.2))
                        Label("Up to \(viewModel.zone.maximumStayMinutes) minutes per stay", systemImage: "hourglass")
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.textLight)
                    }
                    .padding(AppSpacing.xSmall)
                    .background(AppColors.buttonBackground, in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
                }
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        AppSectionHeader(title: "Opening hours")
                        TimelineView(.periodic(from: .now, by: 60)) { clock in
                            let status = viewModel.openingStatus(at: clock.date)
                            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                AppStatusBadge(title: status, appearance: status == "Open now" ? .success : (status == "Closed now" ? .warning : .neutral))
                                Label("\(String(format: "%02d:00", viewModel.zone.openingHour))–\(String(format: "%02d:00", viewModel.zone.closingHour))", systemImage: "clock")
                                    .font(AppTypography.titleSmall)
                            }
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
