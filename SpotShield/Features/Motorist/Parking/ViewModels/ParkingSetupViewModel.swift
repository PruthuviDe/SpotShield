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
    var activeSession: ParkingSession?
    var isLoading = false
    var isLoadingSession = false
    var isStartingParking = false
    var isEndingParking = false
    var errorMessage = ""
    var sessionErrorMessage = ""
    var parkingErrorMessage = ""
    var successMessage = ""
    var selectedMinutes = 0
    var isParkedHere = false

    private let profile: UserProfile
    private let userRepository = UserProfileRepository()
    private let sessionRepository = ParkingSessionRepository()

    private var hasLoadedActiveSession = false
    private var pendingRequestKey = ""
    private var pendingOperationId = ""

    init(profile: UserProfile) {
        self.profile = profile
    }

    func availableDurations(
        zone: ParkingZone,
        at time: Date = Date()
    ) -> [Int] {
        guard zone.isPublished,
              zone.isActive,
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

        guard !isTooLarge else {
            return nil
        }

        return price
    }

    func canStartParking(
        zone: ParkingZone,
        at time: Date = Date()
    ) -> Bool {
        guard profile.role == .motorist,
              vehicle?.ownerUserId == profile.id,
              hasLoadedActiveSession,
              activeSession == nil,
              !isLoading,
              !isLoadingSession,
              !isStartingParking,
              !isEndingParking,
              isParkedHere else {
            return false
        }

        return estimatedPrice(zone: zone, at: time) != nil
    }

    func loadVehicle() async {
        guard !isLoading else {
            return
        }

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
            let savedVehicle = try await userRepository.getVehicle(
                vehicleId: vehicleId
            )

            guard !Task.isCancelled else {
                return
            }

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
            guard !Task.isCancelled else {
                return
            }

            errorMessage = "Could not load your vehicle. Please try again."
        }
    }

    func loadActiveSession() async {
        guard !isLoadingSession else {
            return
        }

        sessionErrorMessage = ""
        hasLoadedActiveSession = false
        isLoadingSession = true

        defer {
            isLoadingSession = false
        }

        do {
            activeSession = try await sessionRepository.getActiveSession(
                userId: profile.id
            )

            guard !Task.isCancelled else {
                return
            }

            hasLoadedActiveSession = true
        } catch {
            guard !Task.isCancelled else {
                return
            }

            sessionErrorMessage =
                "Could not check your current parking session. Please refresh."
        }
    }

    func refresh() async {
        guard !isStartingParking,
              !isEndingParking,
              !isLoading,
              !isLoadingSession else {
            return
        }

        await loadVehicle()
        await loadActiveSession()
    }

    func startParking(zone: ParkingZone) async {
        guard !isStartingParking,
              !isEndingParking,
              !isLoading,
              !isLoadingSession else {
            return
        }

        parkingErrorMessage = ""
        successMessage = ""

        guard hasLoadedActiveSession else {
            parkingErrorMessage =
                "Please refresh before starting parking."
            return
        }

        guard activeSession == nil else {
            parkingErrorMessage =
                "You already have an active parking session."
            return
        }

        guard let vehicle,
              vehicle.ownerUserId == profile.id else {
            parkingErrorMessage =
                "Your vehicle details are not ready."
            return
        }

        guard isParkedHere else {
            parkingErrorMessage =
                "Confirm that you are parked in this zone."
            return
        }

        guard let price = estimatedPrice(zone: zone) else {
            parkingErrorMessage =
                "Choose an available parking time."
            return
        }

        let requestKey = [
            zone.id,
            vehicle.id,
            String(selectedMinutes),
            String(zone.policyVersion)
        ].joined(separator: "|")

        if pendingRequestKey != requestKey {
            pendingRequestKey = requestKey
            pendingOperationId = UUID().uuidString
        }

        isStartingParking = true

        defer {
            isStartingParking = false
        }

        do {
            let sessionId = try await sessionRepository.startParking(
                parkingZoneId: zone.id,
                vehicleId: vehicle.id,
                durationMinutes: selectedMinutes,
                policyVersion: zone.policyVersion,
                isParkedHere: isParkedHere,
                operationId: pendingOperationId
            )

            guard let savedSession = try await sessionRepository.getSession(
                sessionId: sessionId,
                userId: profile.id
            ) else {
                parkingErrorMessage =
                    "Payment succeeded, but the session could not load. Try again to refresh it."
                return
            }

            activeSession = savedSession
            pendingRequestKey = ""
            pendingOperationId = ""
            successMessage = "Parking started. LKR \(price) paid from your demo wallet."
        } catch {
            parkingErrorMessage =
                "Could not start parking: \(error.localizedDescription)"
        }
    }

    func endParking() async {
        guard !isEndingParking,
              !isStartingParking,
              !isLoading,
              !isLoadingSession else {
            return
        }

        parkingErrorMessage = ""
        successMessage = ""

        guard profile.role == .motorist,
              let session = activeSession,
              session.userId == profile.id,
              session.isActive else {
            parkingErrorMessage = "No active parking session was found."
            return
        }

        isEndingParking = true

        defer {
            isEndingParking = false
        }

        do {
            try await sessionRepository.endParking(
                sessionId: session.id
            )

            guard !Task.isCancelled else {
                return
            }

            activeSession = nil
            hasLoadedActiveSession = false
            pendingRequestKey = ""
            pendingOperationId = ""
            selectedMinutes = 0
            isParkedHere = false

            await loadActiveSession()

            guard !Task.isCancelled else {
                return
            }

            successMessage =
                "Parking ended. Your wallet balance has not changed."
        } catch {
            guard !Task.isCancelled else {
                return
            }

            parkingErrorMessage =
                "Could not confirm that parking ended. "
                + "Refresh or try again. "
                + error.localizedDescription
        }
    }
}
