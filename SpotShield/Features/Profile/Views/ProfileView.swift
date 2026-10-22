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
    @State private var isShowingSignOutConfirmation = false
    private let onOpenWallet: (() -> Void)?

    init(profile: UserProfile, onOpenWallet: (() -> Void)? = nil) {
        self.onOpenWallet = onOpenWallet
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
                biometricSection

                AppButton(
                    title: "Sign Out",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    appearance: .destructive
                ) {
                    isShowingSignOutConfirmation = true
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
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
        .confirmationDialog(
            "Sign out of SpotShield?",
            isPresented: $isShowingSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                appState.signOut()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You will need to sign in again to access your account.")
        }
    }

    private var accountCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                AppSectionHeader(title: "Account")
                Text(viewModel.profile.name)
                    .font(AppTypography.titleMedium)

                Text(viewModel.profile.email)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)

                AppStatusBadge(title: viewModel.profile.role.title)
            }
        }
    }

    private var vehicleSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(title: "Vehicle")

                if viewModel.isLoadingVehicle {
                    AppLoadingView(title: "Loading vehicle details…")
                } else if let vehicle = viewModel.vehicle {
                    Label(vehicle.licensePlate, systemImage: "car")
                        .font(AppTypography.bodyBold)

                    let vehicleDescription = "\(vehicle.make) \(vehicle.model)"
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if !vehicleDescription.isEmpty {
                        Text(vehicleDescription)
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                } else {
                    AppMessageView(
                        title: viewModel.vehicleMessage,
                        appearance: .neutral
                    )
                }
            }
        }
    }

    private var walletLink: some View {
        Group {
            if let onOpenWallet {
                Button(action: onOpenWallet) {
                    Label("Wallet settings", systemImage: "wallet.bifold")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(appearance: .secondary))
            } else {
                NavigationLink {
                    WalletView(profile: viewModel.profile)
                } label: {
                    Label("Wallet settings", systemImage: "wallet.bifold")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(appearance: .secondary))
            }
        }
    }

    private var assignmentSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(title: "Assigned patrol zones")

                if viewModel.isLoadingZones {
                    AppLoadingView(title: "Loading assigned zones…")
                } else if !viewModel.assignmentError.isEmpty {
                    AppMessageView(
                        title: viewModel.assignmentError,
                        appearance: .error
                    )
                } else if viewModel.assignedZones.isEmpty {
                    AppMessageView(
                        title: "No patrol zones assigned",
                        message: "Your active patrol assignments will appear here.",
                        appearance: .neutral
                    )
                } else {
                    ForEach(viewModel.assignedZones) { zone in
                        Label(zone.name, systemImage: "mappin.and.ellipse")
                            .font(AppTypography.bodyBold)
                    }
                }

                AppButton(
                    title: "Refresh assignments",
                    systemImage: "arrow.clockwise",
                    appearance: .secondary,
                    isLoading: viewModel.isLoadingZones
                ) {
                    Task {
                        await viewModel.loadAssignedZones()
                    }
                }
            }
        }
    }

    private var notificationsSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(
                    title: viewModel.profile.role == .motorist
                        ? "Parking reminders"
                        : "Notifications"
                )

                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text("Notification access")
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer(minLength: AppSpacing.small)
                        notificationBadge
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text("Notification access")
                            .foregroundStyle(AppColors.textSecondary)
                        notificationBadge
                    }
                }

                if !viewModel.notificationError.isEmpty {
                    AppMessageView(
                        title: viewModel.notificationError,
                        appearance: .error
                    )
                }

                AppButton(
                    title: notificationButtonTitle,
                    systemImage: notificationButtonImage,
                    appearance: .secondary,
                    isLoading: viewModel.isRequestingNotifications
                ) {
                    if viewModel.notificationStatus == "Not requested" {
                        Task {
                            await viewModel.requestNotifications()
                        }
                    } else if let settingsURL = URL(
                        string: UIApplication.openSettingsURLString
                    ) {
                        openURL(settingsURL)
                    }
                }
                .disabled(viewModel.notificationStatus == "Checking...")
            }
        }
    }

    private var biometricSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(title: "Secure access")

                Toggle(
                    "Use \(viewModel.biometricDeviceName)",
                    isOn: Binding(
                        get: { viewModel.isBiometricEnabled },
                        set: { isEnabled in
                            Task {
                                await viewModel.setBiometricEnabled(isEnabled)
                            }
                        }
                    )
                )
                .tint(AppColors.accent)
                .disabled(
                    viewModel.isUpdatingBiometric
                        || (!viewModel.isBiometricAvailable && !viewModel.isBiometricEnabled)
                )

                Text("Require biometric authentication when you return to SpotShield.")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)

                if !viewModel.isBiometricAvailable {
                    AppMessageView(
                        title: "Set up Face ID or Touch ID on this device to enable secure access.",
                        appearance: .neutral
                    )
                }

                if !viewModel.biometricError.isEmpty {
                    AppMessageView(
                        title: viewModel.biometricError,
                        appearance: .error
                    )
                }
            }
        }
    }

    private var notificationBadge: some View {
        AppStatusBadge(
            title: viewModel.notificationStatus,
            appearance: notificationAppearance
        )
    }

    private var notificationAppearance: AppStatusAppearance {
        switch viewModel.notificationStatus {
        case "Allowed", "Allowed quietly": .success
        case "Temporary access": .warning
        case "Off", "Unavailable": .error
        default: .neutral
        }
    }

    private var notificationButtonTitle: String {
        viewModel.notificationStatus == "Not requested"
            ? "Enable Notifications"
            : "Open iPhone Settings"
    }

    private var notificationButtonImage: String {
        viewModel.notificationStatus == "Not requested"
            ? "bell.badge"
            : "gearshape"
    }

}
