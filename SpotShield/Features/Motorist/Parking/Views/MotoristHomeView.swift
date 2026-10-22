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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                AppSectionHeader(title: "Welcome, \(profile.name)", subtitle: "Find your zone and keep track of your parking.")
                currentParking

                NavigationLink {
                    MotoristParkingView()
                } label: {
                    Label("Find Parking", systemImage: "map")
                }
                .buttonStyle(AppButtonStyle(appearance: viewModel.session == nil ? .primary : .secondary))

                if profile.primaryVehicleId == nil {
                    AppMessageView(title: "Add your vehicle", message: "Save your license plate before starting parking.")
                    NavigationLink {
                        DriverSetupView(profile: profile)
                    } label: {
                        Label("Add Vehicle", systemImage: "car")
                    }
                    .buttonStyle(AppButtonStyle(appearance: .secondary))
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
        .task { await viewModel.loadSession(userId: profile.id) }
        .refreshable { await viewModel.loadSession(userId: profile.id) }
    }

    private var currentParking: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(title: "Current parking")
                if viewModel.isLoading {
                    AppLoadingView(title: "Checking your parking…")
                } else if !viewModel.errorMessage.isEmpty {
                    AppMessageView(title: viewModel.errorMessage, appearance: .error)
                } else if let session = viewModel.session {
                    TimelineView(.periodic(from: .now, by: 1)) { clock in
                        VStack(alignment: .leading, spacing: AppSpacing.medium) {
                            AppStatusBadge(
                                title: session.paidUntil > clock.date ? "Parking active" : "Paid time expired",
                                appearance: session.paidUntil > clock.date ? .success : .error
                            )
                            Text(session.zoneName).font(AppTypography.titleMedium)
                            Label(session.licensePlate, systemImage: "car")
                                .font(AppTypography.bodyBold)
                            if session.paidUntil > clock.date {
                                Text(timerInterval: clock.date...session.paidUntil, countsDown: true)
                                    .font(AppTypography.timerDisplay)
                                    .accessibilityLabel("Parking time remaining")
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
                        }
                    }
                } else {
                    Label("Ready when you are", systemImage: "parkingsign.circle")
                        .font(AppTypography.titleMedium)
                    Text("Choose a parking zone to start your next session.")
                        .foregroundStyle(AppColors.textSecondary)
                }
                if NotificationManager.shared.isParkingReminderUnavailable {
                    AppMessageView(title: "Parking reminder unavailable", message: "Check SpotShield notifications in iPhone Settings.", appearance: .warning)
                }
                AppButton(title: "Refresh Parking", systemImage: "arrow.clockwise", appearance: .secondary) {
                    Task { await viewModel.loadSession(userId: profile.id) }
                }
                .disabled(viewModel.isLoading)
            }
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
