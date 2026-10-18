//
//  ParkingSetupViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import Foundation
import Observation

@MainActor
@Observable
final class ParkingSetupViewModel {
    var vehicle: Vehicle?
    var isLoading = false
    var errorMessage = ""
    var selectedMinutes = 0
    var isParkedHere = false

    private let profile: UserProfile
    private let repository = UserProfileRepository()

    init(profile: UserProfile) {
        self.profile = profile
    }

    func availableDurations(
        zone: ParkingZone,
        at time: Date = Date()
    ) -> [Int] {
        guard zone.isPublished, zone.isActive,
              zone.openingHour >= 0,
              zone.openingHour <= 23,
              zone.closingHour > zone.openingHour,
              zone.closingHour <= 24,
              let timeZone = TimeZone(identifier: zone.timeZoneId) else {
            return []
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let currentHour = calendar.component(.hour, from: time)

        guard currentHour >= zone.openingHour,
              currentHour < zone.closingHour else {
            return []
        }

        let startOfDay = calendar.startOfDay(for: time)

        guard let closingTime = calendar.date(
            byAdding: .hour,
            value: zone.closingHour,
            to: startOfDay
        ) else {
            return []
        }

        var durations: [Int] = []

        for minutes in [30, 60, 120] {
            let endTime = time.addingTimeInterval(
                TimeInterval(minutes * 60)
            )

            if minutes <= zone.maximumStayMinutes,
               endTime <= closingTime {
                durations.append(minutes)
            }
        }

        return durations
    }

    func estimatedPrice(
        zone: ParkingZone,
        at time: Date = Date()
    ) -> Int? {
        guard vehicle != nil,
              zone.hourlyRateLKR > 0,
              availableDurations(zone: zone, at: time)
                .contains(selectedMinutes) else {
            return nil
        }

        if selectedMinutes == 30 {
            let halfPrice = zone.hourlyRateLKR / 2
            let extraRupee = zone.hourlyRateLKR % 2

            return halfPrice + extraRupee
        }

        let hours = selectedMinutes / 60
        let (price, isTooLarge) = zone.hourlyRateLKR
            .multipliedReportingOverflow(by: hours)

        guard !isTooLarge else { return nil }

        return price
    }

    func loadVehicle() async {
        guard !isLoading else { return }

        vehicle = nil
        errorMessage = ""

        guard profile.role == .motorist else {
            errorMessage = "Only Drivers can start parking."
            return
        }

        guard let vehicleId = profile.primaryVehicleId,
              !vehicleId.isEmpty else {
            errorMessage = "Please add a vehicle before starting parking."
            return
        }

        isLoading = true

        defer {
            isLoading = false
        }

        do {
            let savedVehicle = try await repository.getVehicle(
                vehicleId: vehicleId
            )

            guard !Task.isCancelled else { return }

            guard let savedVehicle else {
                errorMessage = "Your vehicle details could not be found."
                return
            }

            guard savedVehicle.ownerUserId == profile.id else {
                errorMessage = "This vehicle does not belong to your account."
                return
            }

            let plate = savedVehicle.licensePlate
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !plate.isEmpty else {
                errorMessage = "Your vehicle needs a license plate."
                return
            }

            vehicle = savedVehicle
        } catch {
            guard !Task.isCancelled else { return }

            errorMessage = "Could not load your vehicle. Please try again."
        }
    }
}
