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

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundStyle(AppColors.statusOverstay)
                }

                if let vehicle = viewModel.vehicle {
                    vehicleDetails(vehicle: vehicle)
                    durationDetails
                }

                Button("Refresh Vehicle") {
                    Task {
                        await viewModel.loadVehicle()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.large)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.textPrimary)
        .navigationTitle("Parking Setup")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadVehicle()
        }
    }

    private var durationDetails: some View {
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
                        + "The zone may be closed, inactive, "
                        + "or too close to closing time."
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

                    Text("Prices are rounded up to the next whole rupee.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    Text("Ending parking early will not refund unused time.")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)

                    Toggle(
                        "I am parked in this zone",
                        isOn: $viewModel.isParkedHere
                    )
                    .tint(AppColors.statusValid)

                    Text("Parking starts only after payment is confirmed.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
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
}
