//
//  ParkingZoneFormView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import SwiftUI

struct ParkingZoneFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ParkingZoneFormViewModel

    init(zone: ParkingZone? = nil) {
        _viewModel = State(
            initialValue: ParkingZoneFormViewModel(zone: zone)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                zoneDetails
                locationDetails
                parkingHours
                saveSection
            }
            .font(AppTypography.bodyMedium)
            .foregroundStyle(AppColors.textPrimary)
            .tint(AppColors.textPrimary)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .scrollDismissesKeyboard(.interactively)
            .disabled(viewModel.isSaving)
            .navigationTitle(
                viewModel.isEditing ? "Edit Zone" : "Create Zone"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    private var zoneDetails: some View {
        Section("Zone details") {
            LabeledContent("Name") {
                TextField("Zone name", text: $viewModel.name)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
            }

            LabeledContent("Hourly price (LKR)") {
                TextField("150", text: $viewModel.hourlyRateLKR)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
        }
        .listRowBackground(AppColors.card)
    }

    private var locationDetails: some View {
        Section {
            LabeledContent("Latitude") {
                TextField("6.9271", text: $viewModel.latitude)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("Longitude") {
                TextField("79.8612", text: $viewModel.longitude)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("Radius (metres)") {
                TextField("100", text: $viewModel.radiusMeters)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Zone location")
        } footer: {
            Text("Enter the zone centre and a boundary radius up to 1,000 metres.")
        }
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .listRowBackground(AppColors.card)
    }

    private var parkingHours: some View {
        Section {
            Picker("Opening hour", selection: $viewModel.openingHour) {
                ForEach(0..<24, id: \.self) { hour in
                    Text("\(hour):00")
                        .tag(hour)
                }
            }

            Picker("Closing hour", selection: $viewModel.closingHour) {
                ForEach(1..<25, id: \.self) { hour in
                    Text("\(hour):00")
                        .tag(hour)
                }
            }

            Stepper(
                value: $viewModel.maximumStayMinutes,
                in: 1...1440
            ) {
                VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                    Text("Maximum parking time")
                    
                    Text("\(viewModel.maximumStayMinutes) minutes")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        } header: {
            Text("Parking hours")
        } footer: {
            Text(
                "Times use Sri Lanka time in 24-hour format. "
                + "24:00 means midnight at the end of the day."
            )
        }
        .listRowBackground(AppColors.card)
    }

    private var saveSection: some View {
        Section {
            if viewModel.isEditing {
                Text(
                    "Saving changes keeps the zone's current publishing status. "
                    + "Use Parking Zones to publish, activate or deactivate it."
                )
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
            } else {
                Text(
                    "New zones are saved as drafts. "
                    + "Assign a Warden, then publish from Parking Zones."
                )
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
            }

            if !viewModel.errorMessage.isEmpty {
                AppMessageView(
                    title: "Check the zone details",
                    message: viewModel.errorMessage,
                    appearance: .error
                )
            }

            AppButton(
                title: saveButtonTitle,
                systemImage: viewModel.isEditing ? "checkmark" : "plus",
                isLoading: viewModel.isSaving
            ) {
                Task {
                    let wasSaved = await viewModel.saveZone()

                    if wasSaved {
                        dismiss()
                    }
                }
            }
        }
        .listRowBackground(AppColors.card)
    }

    private var saveButtonTitle: String {
        viewModel.isEditing ? "Save Changes" : "Save Draft"
    }
}
