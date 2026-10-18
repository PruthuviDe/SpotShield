//
//  ParkingSetupView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import SwiftUI

struct ParkingSetupView: View {
    let zone: ParkingZone

    @State private var viewModel: ParkingSetupViewModel

    init(zone: ParkingZone, profile: UserProfile) {
        self.zone = zone
        _viewModel = State(
            initialValue: ParkingSetupViewModel(profile: profile)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                Text(zone.name)
                    .font(AppTypography.titleMedium)

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
                } else if viewModel.vehicle != nil,
                          !viewModel.isLoadingSession,
                          viewModel.sessionErrorMessage.isEmpty {
                    parkingDetails
                }

                Button("Refresh") {
                    Task {
                        await viewModel.refresh()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(
                    viewModel.isLoading
                    || viewModel.isLoadingSession
                    || viewModel.isStartingParking
                    || viewModel.isEndingParking
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.large)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Parking Setup")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refresh()
        }
    }

    private var parkingDetails: some View {
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

                    Button {
                        Task {
                            await viewModel.startParking(zone: zone)
                        }
                    } label: {
                        HStack {
                            if viewModel.isStartingParking {
                                ProgressView()
                                    .tint(AppColors.accent)
                            }

                            Text(
                                viewModel.isStartingParking
                                    ? "Starting..."
                                    : "Start parking • LKR \(price)"
                            )
                            .font(AppTypography.bodyBold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.medium)
                        .background(
                            AppColors.buttonBackground,
                            in: RoundedRectangle(
                                cornerRadius: AppSpacing.radiusPill
                            )
                        )
                        .foregroundStyle(AppColors.accent)
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
            .onChange(of: durations) { _, newDurations in
                if !newDurations.contains(viewModel.selectedMinutes) {
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
        let paidUntil = session.paidUntil.formatted(
            date: .abbreviated,
            time: .shortened
        )

        return VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Open parking session")
                .font(AppTypography.titleSmall)

            Text(session.zoneName)
                .font(AppTypography.bodyBold)

            Text(session.licensePlate)
                .font(AppTypography.bodyBold)

            Text("Paid until \(paidUntil)")
                .foregroundStyle(AppColors.textSecondary)

            Text("Paid: LKR \(session.totalPaidLKR)")
                .foregroundStyle(AppColors.textSecondary)

            Text("Ending parking early will not refund unused time.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

            Button {
                Task {
                    await viewModel.endParking()
                }
            } label: {
                HStack {
                    if viewModel.isEndingParking {
                        ProgressView()
                            .tint(AppColors.accent)
                    }

                    Text(
                        viewModel.isEndingParking
                            ? "Ending..."
                            : "End Parking"
                    )
                    .font(AppTypography.bodyBold)
                }
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.medium)
                .background(
                    AppColors.buttonBackground,
                    in: RoundedRectangle(
                        cornerRadius: AppSpacing.radiusPill
                    )
                )
                .foregroundStyle(AppColors.accent)
            }
            .disabled(
                viewModel.isLoading
                || viewModel.isLoadingSession
                || viewModel.isStartingParking
                || viewModel.isEndingParking
            )
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
