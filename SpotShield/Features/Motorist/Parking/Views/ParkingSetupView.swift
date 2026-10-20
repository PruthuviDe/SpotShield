//
//  ParkingSetupView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import SwiftUI

struct ParkingSetupView: View {
    let zone: ParkingZone?

    @State private var viewModel: ParkingSetupViewModel
    @State private var isShowingEndConfirmation = false
    @State private var sessionToEndId = ""

    init(zone: ParkingZone, profile: UserProfile) {
        self.zone = zone
        _viewModel = State(
            initialValue: ParkingSetupViewModel(profile: profile)
        )
    }

    init(profile: UserProfile) {
        self.zone = nil
        _viewModel = State(
            initialValue: ParkingSetupViewModel(profile: profile)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if let zone {
                    Text(zone.name)
                        .font(AppTypography.titleMedium)
                } else if let session = viewModel.activeSession {
                    Text(session.zoneName)
                        .font(AppTypography.titleMedium)
                }

                if viewModel.isLoading {
                    ProgressView("Loading your vehicle...")
                }

                if viewModel.isLoadingSession {
                    ProgressView("Checking your parking session...")
                }

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundStyle(AppColors.statusOverstay)
                }

                if !viewModel.sessionErrorMessage.isEmpty {
                    Text(viewModel.sessionErrorMessage)
                        .foregroundStyle(AppColors.statusOverstay)
                }

                if !viewModel.parkingErrorMessage.isEmpty {
                    Text(viewModel.parkingErrorMessage)
                        .foregroundStyle(AppColors.statusOverstay)
                }

                if !viewModel.successMessage.isEmpty {
                    Text(viewModel.successMessage)
                        .foregroundStyle(AppColors.statusValid)
                }

                if let vehicle = viewModel.vehicle {
                    vehicleDetails(vehicle: vehicle)
                }

                if let session = viewModel.activeSession {
                    activeSessionDetails(session: session)
                } else if let zone = zone,
                          viewModel.vehicle != nil,
                          !viewModel.isLoadingSession,
                          viewModel.sessionErrorMessage.isEmpty {
                    parkingDetails(zone: zone)
                } else if zone == nil,
                          !viewModel.isLoadingSession,
                          viewModel.sessionErrorMessage.isEmpty {
                    Text("You have no active parking session.")
                        .foregroundStyle(AppColors.textSecondary)
                }

                Button("Refresh") {
                    Task {
                        await loadScreen()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isBusy)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.large)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(zone == nil ? "Manage Parking" : "Parking Setup")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadScreen()
        }
        .confirmationDialog(
            "End parking? Unused time will not be refunded.",
            isPresented: $isShowingEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Parking", role: .destructive) {
                Task {
                    guard viewModel.activeSession?.id == sessionToEndId else {
                        viewModel.parkingErrorMessage =
                            "Your parking session changed. Refresh and check it before ending."
                        return
                    }
                    await viewModel.endParking()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func loadScreen() async {
        if zone == nil {
            await viewModel.loadActiveSession()
        } else {
            await viewModel.refresh()
        }
    }

    private func parkingDetails(zone: ParkingZone) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { clock in
            let durations = viewModel.availableDurations(
                zone: zone,
                at: clock.date
            )

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text("Parking time")
                    .font(AppTypography.titleSmall)

                if durations.isEmpty {
                    Text(
                        "No parking time is available. "
                        + "The zone may be closed or too close to closing time."
                    )
                    .foregroundStyle(AppColors.textSecondary)
                } else {
                    Picker(
                        "Choose your parking time",
                        selection: $viewModel.selectedMinutes
                    ) {
                        Text("Choose a duration")
                            .tag(0)

                        ForEach(durations, id: \.self) { minutes in
                            Text("\(minutes) minutes")
                                .tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if let price = viewModel.estimatedPrice(
                    zone: zone,
                    at: clock.date
                ) {
                    Divider()

                    Text("Estimated price")
                        .font(AppTypography.titleSmall)

                    Text("LKR \(price)")
                        .font(AppTypography.priceDisplay)

                    Text("These are demo funds. No real money is involved.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    Toggle(
                        "I am parked in this zone",
                        isOn: $viewModel.isParkedHere
                    )
                    .tint(AppColors.statusValid)

                    actionButton(
                        viewModel.isStartingParking
                            ? "Starting..."
                            : "Start parking • LKR \(price)",
                        isLoading: viewModel.isStartingParking
                    ) {
                        Task {
                            await viewModel.startParking(zone: zone)
                        }
                    }
                    .disabled(
                        !viewModel.canStartParking(
                            zone: zone,
                            at: clock.date
                        )
                    )
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
            .disabled(viewModel.isBusy)
            .onChange(of: durations) { _, newDurations in
                if !viewModel.isBusy,
                   !newDurations.contains(viewModel.selectedMinutes) {
                    viewModel.selectedMinutes = 0
                    viewModel.isParkedHere = false
                }
            }
        }
    }

    private func vehicleDetails(vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Your vehicle")
                .font(AppTypography.titleSmall)

            Text(vehicle.licensePlate)
                .font(AppTypography.titleMedium)

            Text("Check that this is the vehicle you are parking.")
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

    private func activeSessionDetails(
        session: ParkingSession
    ) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { clock in
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(session.paidUntil > clock.date
                     ? "Parking is active" : "Paid time has expired")
                    .font(AppTypography.titleSmall)
                    .foregroundStyle(session.paidUntil > clock.date
                                     ? AppColors.statusValid : AppColors.statusOverstay)

                Text(session.zoneName)
                    .font(AppTypography.bodyBold)

                Text(session.licensePlate)
                    .font(AppTypography.bodyBold)

                Text("Paid until \(formattedDate(session.paidUntil))")
                    .foregroundStyle(AppColors.textSecondary)

                Text("Paid: LKR \(session.totalPaidLKR)")
                    .foregroundStyle(AppColors.textSecondary)

                Divider()
                extensionDetails(at: clock.date)
                Divider()

                Text("Ending parking early will not refund unused time.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                actionButton(
                    viewModel.isEndingParking ? "Ending..." : "End Parking",
                    isLoading: viewModel.isEndingParking
                ) {
                    sessionToEndId = session.id
                    isShowingEndConfirmation = true
                }
                .disabled(viewModel.isBusy)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.medium)
            .background(
                AppColors.card,
                in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard)
            )
        }
    }

    private func extensionDetails(at time: Date) -> some View {
        let durations = viewModel.extensionDurations(at: time)

        return VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Extend parking")
                .font(AppTypography.titleSmall)

            if durations.isEmpty {
                Text("No extra time is available within this session's limits.")
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Picker("Add parking time", selection: $viewModel.selectedExtensionMinutes) {
                    Text("Choose extra time").tag(0)
                    ForEach(durations, id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
                .pickerStyle(.menu)

                if let price = viewModel.extensionPrice(at: time),
                   let session = viewModel.activeSession {
                    let newEndTime = session.paidUntil.addingTimeInterval(
                        TimeInterval(viewModel.selectedExtensionMinutes * 60)
                    )

                    Text("Extension price: LKR \(price)")
                        .font(AppTypography.bodyBold)
                    Text("New paid until: \(formattedDate(newEndTime))")
                        .foregroundStyle(AppColors.textSecondary)
                    Text("Extra time starts from your current paid-until time.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    actionButton(
                        viewModel.isExtendingParking
                            ? "Extending..." : "Extend parking • LKR \(price)",
                        isLoading: viewModel.isExtendingParking
                    ) {
                        Task {
                            await viewModel.extendParking()
                        }
                    }
                    .disabled(!viewModel.canExtendParking(at: time))
                }
            }
        }
        .disabled(viewModel.isBusy)
        .onChange(of: durations) { _, newDurations in
            if !viewModel.isBusy,
               !newDurations.contains(viewModel.selectedExtensionMinutes) {
                viewModel.selectedExtensionMinutes = 0
            }
        }
    }

    private func actionButton(
        _ title: String,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView().tint(AppColors.accent)
                }
                Text(title).font(AppTypography.bodyBold)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.medium)
            .background(
                AppColors.buttonBackground,
                in: RoundedRectangle(cornerRadius: AppSpacing.radiusPill)
            )
            .foregroundStyle(AppColors.accent)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: "Asia/Colombo")
        return formatter.string(from: date)
    }
}
