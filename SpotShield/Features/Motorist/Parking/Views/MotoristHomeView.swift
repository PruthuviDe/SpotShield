//
//  MotoristHomeView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import SwiftUI

struct MotoristHomeView: View {
    let profile: UserProfile
    @State private var viewModel = MotoristHomeViewModel()
    @State private var refreshErrorMessage = ""
    @State private var isShowingRefreshError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                welcomeHeader
                currentParking

                if profile.primaryVehicleId == nil {
                    vehicleSetupCard
                }
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Park")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.loadSession(userId: profile.id) }
                } label: {
                    Label("Refresh parking", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .refreshOnAppearAndForeground { await viewModel.loadSession(userId: profile.id) }
        .refreshable { await viewModel.loadSession(userId: profile.id) }
        .onChange(of: viewModel.errorMessage) { _, message in
            guard !message.isEmpty, viewModel.session != nil else { return }
            refreshErrorMessage = message
            isShowingRefreshError = true
        }
        .alert("Could not refresh parking", isPresented: $isShowingRefreshError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(refreshErrorMessage)
        }
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("Welcome, \(profile.name)")
                .font(AppTypography.titleLarge)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("Find a zone or manage your current session.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, AppSpacing.small)
    }

    private var currentParking: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: "Current parking")

            if viewModel.session == nil && viewModel.isLoading {
                AppCard {
                    AppLoadingView(title: "Checking your parking…")
                }
            } else if let session = viewModel.session {
                activeParkingCard(session: session)
            } else if !viewModel.errorMessage.isEmpty {
                AppMessageView(
                    title: viewModel.errorMessage,
                    appearance: .error,
                    actionTitle: "Try Again",
                    action: { Task { await viewModel.loadSession(userId: profile.id) } }
                )
            } else {
                parkingDiscoveryCard
            }

            if NotificationManager.shared.isParkingReminderUnavailable {
                AppMessageView(title: "Parking reminder unavailable", message: "Check SpotShield notifications in iPhone Settings.", appearance: .warning)
            }

        }
    }

    private var parkingDiscoveryCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                HStack(alignment: .top, spacing: AppSpacing.medium) {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text("Ready for your next stop")
                            .font(AppTypography.titleMedium)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Explore nearby zones and compare rates before you park.")
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "map.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 76, height: 76)
                        .background(
                            AppColors.buttonBackground,
                            in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard)
                        )
                        .accessibilityHidden(true)
                }

                NavigationLink {
                    MotoristParkingView(profile: profile)
                } label: {
                    Label("Find Parking", systemImage: "map")
                }
                .buttonStyle(AppButtonStyle())
            }
            .padding(.vertical, AppSpacing.small)
        }
    }

    private func activeParkingCard(session: ParkingSession) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                HStack {
                    TimelineView(.periodic(from: .now, by: 1)) { clock in
                        AppStatusBadge(
                            title: session.paidUntil > clock.date ? "Parking active" : "Paid time expired",
                            appearance: session.paidUntil > clock.date ? .success : .error
                        )
                    }

                    Spacer()

                    Image(systemName: "parkingsign.circle")
                        .font(.system(size: 34))
                        .foregroundStyle(AppColors.accent)
                        .accessibilityHidden(true)
                }

                Text(session.zoneName)
                    .font(AppTypography.titleLarge)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Label(session.licensePlate, systemImage: "car.fill")
                    .font(AppTypography.bodyBold)
                    .foregroundStyle(AppColors.textPrimary)

                TimelineView(.periodic(from: .now, by: 1)) { clock in
                    let isActive = session.paidUntil > clock.date

                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(isActive ? "TIME REMAINING" : "PAID TIME EXPIRED")
                            .font(AppTypography.captionBold)

                        if isActive {
                            Text(timerInterval: clock.date...session.paidUntil, countsDown: true)
                                .font(AppTypography.timerDisplay)
                                .accessibilityLabel("Parking time remaining")
                        } else {
                            Text("Manage parking to review this session.")
                                .font(AppTypography.bodySmall)
                        }
                    }
                    .foregroundStyle(isActive ? AppColors.statusValid : AppColors.statusOverstay)
                    .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                    .padding(AppSpacing.medium)
                    .background(
                        isActive ? AppColors.statusValidBackground : AppColors.statusOverstayBackground,
                        in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard)
                    )
                }

                Text("Paid until \(parkingDate(session.paidUntil))")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)

                NavigationLink {
                    ParkingSetupView(profile: profile)
                } label: {
                    Text("Manage Parking")
                }
                .buttonStyle(AppButtonStyle())

                NavigationLink {
                    MotoristParkingView(profile: profile)
                } label: {
                    Label("Find Parking", systemImage: "map")
                }
                .buttonStyle(AppButtonStyle(appearance: .secondary))
            }
            .padding(.vertical, AppSpacing.small)
        }
    }

    private var vehicleSetupCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Label("Vehicle setup", systemImage: "car.fill")
                    .font(AppTypography.titleSmall)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Save your license plate before starting a parking session.")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                NavigationLink {
                    DriverSetupView(profile: profile)
                } label: {
                    Label("Add Vehicle", systemImage: "plus")
                }
                .buttonStyle(AppButtonStyle(appearance: .secondary))
            }
            .padding(.vertical, AppSpacing.small)
        }
    }

    private func parkingDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: "Asia/Colombo")
        return formatter.string(from: date)
    }
}
