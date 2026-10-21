//
//  ProfileView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: ProfileViewModel

    init(profile: UserProfile) {
        _viewModel = State(
            initialValue: ProfileViewModel(profile: profile)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                accountCard

                if viewModel.profile.role == .motorist {
                    vehicleSection
                    walletLink
                } else if viewModel.profile.role == .warden {
                    assignmentSection
                }

                notificationsSection

                Button("Sign Out", role: .destructive) {
                    appState.signOut()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.large)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Profile & Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await viewModel.refreshNotificationStatus()
                }
            }
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(viewModel.profile.name)
                .font(AppTypography.titleSmall)

            Text(viewModel.profile.email)
                .foregroundStyle(AppColors.textSecondary)

            Text(viewModel.profile.role.title)
                .font(AppTypography.bodyBold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(
            AppColors.card,
            in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard)
        )
    }

    private var vehicleSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Vehicle")
                .font(AppTypography.titleSmall)

            if viewModel.isLoadingVehicle {
                ProgressView("Loading vehicle...")
            } else if let vehicle = viewModel.vehicle {
                Text(vehicle.licensePlate)
                    .font(AppTypography.bodyBold)

                let vehicleDescription = "\(vehicle.make) \(vehicle.model)"
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !vehicleDescription.isEmpty {
                    Text(vehicleDescription)
                        .foregroundStyle(AppColors.textSecondary)
                }
            } else {
                Text(viewModel.vehicleMessage)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(
            AppColors.card,
            in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard)
        )
    }

    private var walletLink: some View {
        NavigationLink {
            WalletView(profile: viewModel.profile)
        } label: {
            Text("Wallet settings")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Assigned patrol zones")
                .font(AppTypography.titleSmall)

            if viewModel.isLoadingZones {
                ProgressView("Loading assigned zones...")
            } else if !viewModel.assignmentError.isEmpty {
                Text(viewModel.assignmentError)
                    .foregroundStyle(AppColors.statusOverstay)
            } else if viewModel.assignedZones.isEmpty {
                Text("No active parking zones are assigned to you.")
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                ForEach(viewModel.assignedZones) { zone in
                    Text(zone.name)
                        .font(AppTypography.bodyBold)
                }

                Text("Only active zones currently available for patrol are shown.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Button("Refresh assignments") {
                Task {
                    await viewModel.loadAssignedZones()
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoadingZones)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(
            AppColors.card,
            in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard)
        )
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(viewModel.profile.role == .motorist ? "Parking reminders" : "Notifications")
                .font(AppTypography.titleSmall)

            Text("Notification access: \(viewModel.notificationStatus)")
                .foregroundStyle(AppColors.textSecondary)

            if !viewModel.notificationError.isEmpty {
                Text(viewModel.notificationError)
                    .foregroundStyle(AppColors.statusOverstay)
            }

            Button {
                if viewModel.notificationStatus == "Not requested" {
                    Task {
                        await viewModel.requestNotifications()
                    }
                } else if let settingsURL = URL(
                    string: UIApplication.openSettingsURLString
                ) {
                    openURL(settingsURL)
                }
            } label: {
                if viewModel.isRequestingNotifications {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(
                        viewModel.notificationStatus == "Not requested"
                            ? "Enable Notifications"
                            : "Open iPhone Settings"
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .disabled(
                viewModel.notificationStatus == "Checking..."
                    || viewModel.isRequestingNotifications
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(
            AppColors.card,
            in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard)
        )
    }
}
