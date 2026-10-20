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
    var isExtendingParking = false
    var errorMessage = ""
    var sessionErrorMessage = ""
    var parkingErrorMessage = ""
    var successMessage = ""
    var selectedMinutes = 0
    var selectedExtensionMinutes = 0
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

    var isBusy: Bool {
        isLoading || isLoadingSession || isStartingParking
            || isEndingParking || isExtendingParking
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
              let closingTime = closingTime(
                on: time,
                hour: zone.closingHour,
                timeZoneId: zone.timeZoneId
              ),
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

        return parkingPrice(rate: zone.hourlyRateLKR, minutes: selectedMinutes)
    }

    func canStartParking(
        zone: ParkingZone,
        at time: Date = Date()
    ) -> Bool {
        guard profile.role == .motorist,
              vehicle?.ownerUserId == profile.id,
              hasLoadedActiveSession,
              activeSession == nil,
              !isBusy,
              isParkedHere else {
            return false
        }

        return estimatedPrice(zone: zone, at: time) != nil
    }

    func extensionDurations(at time: Date = Date()) -> [Int] {
        guard let session = activeSession,
              session.isActive,
              session.startTime <= time,
              session.paidUntil > time,
              let maximumMinutes = session.maximumStayMinutes,
              let closingHour = session.closingHour,
              let timeZoneId = session.timeZoneId,
              let closingTime = closingTime(
                on: session.startTime,
                hour: closingHour,
                timeZoneId: timeZoneId
              ) else {
            return []
        }

        var durations: [Int] = []

        for minutes in [30, 60, 120] {
            let newEndTime = session.paidUntil.addingTimeInterval(
                TimeInterval(minutes * 60)
            )

            if minutes <= maximumMinutes - session.durationMinutes,
               newEndTime <= closingTime {
                durations.append(minutes)
            }
        }

        return durations
    }

    func extensionPrice(at time: Date = Date()) -> Int? {
        guard let session = activeSession,
              extensionDurations(at: time).contains(selectedExtensionMinutes) else {
            return nil
        }

        return parkingPrice(
            rate: session.hourlyRateLKR,
            minutes: selectedExtensionMinutes
        )
    }

    func canExtendParking(at time: Date = Date()) -> Bool {
        profile.role == .motorist
            && activeSession?.userId == profile.id
            && hasLoadedActiveSession
            && !isBusy
            && extensionPrice(at: time) != nil
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
            let savedSession = try await sessionRepository.getActiveSession(
                userId: profile.id
            )

            guard !Task.isCancelled else {
                return
            }

            if savedSession?.id != activeSession?.id
                || savedSession?.durationMinutes != activeSession?.durationMinutes {
                selectedExtensionMinutes = 0
            }

            activeSession = savedSession
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
        guard !isBusy else {
            return
        }

        await loadVehicle()
        await loadActiveSession()
    }

    func startParking(zone: ParkingZone) async {
        guard !isBusy else {
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
            "start",
            zone.id,
            vehicle.id,
            String(selectedMinutes),
            String(zone.policyVersion)
        ].joined(separator: "|")

        let requestId = operationId(for: requestKey)

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
                operationId: requestId
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
            selectedExtensionMinutes = 0
            pendingRequestKey = ""
            pendingOperationId = ""
            successMessage = "Parking started. LKR \(price) paid from your demo wallet."
        } catch {
            parkingErrorMessage =
                "Could not start parking: \(error.localizedDescription)"
        }
    }

    func endParking() async {
        guard !isBusy else {
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
            selectedExtensionMinutes = 0
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

    func extendParking() async {
        guard !isBusy else {
            return
        }

        parkingErrorMessage = ""
        successMessage = ""

        guard canExtendParking(), let session = activeSession else {
            parkingErrorMessage = "Choose an available extension time."
            return
        }

        let minutes = selectedExtensionMinutes
        let requestKey = [
            "extend",
            session.id,
            String(session.durationMinutes),
            String(minutes)
        ].joined(separator: "|")
        let requestId = operationId(for: requestKey)

        isExtendingParking = true

        defer {
            isExtendingParking = false
        }

        do {
            let amountLKR = try await sessionRepository.extendParking(
                sessionId: session.id,
                additionalMinutes: minutes,
                expectedDurationMinutes: session.durationMinutes,
                operationId: requestId
            )

            guard !Task.isCancelled else {
                return
            }

            activeSession = nil
            selectedExtensionMinutes = 0
            pendingRequestKey = ""
            pendingOperationId = ""

            await loadActiveSession()

            guard !Task.isCancelled else {
                return
            }

            successMessage = "Parking extended. LKR \(amountLKR) paid from your demo wallet."
        } catch {
            guard !Task.isCancelled else {
                return
            }

            parkingErrorMessage = "Could not confirm the extension: \(error.localizedDescription)"
            await loadActiveSession()
        }
    }

    private func operationId(for requestKey: String) -> String {
        if pendingRequestKey != requestKey {
            pendingRequestKey = requestKey
            pendingOperationId = UUID().uuidString
        }

        return pendingOperationId
    }

    private func parkingPrice(rate: Int, minutes: Int) -> Int? {
        guard rate > 0, [30, 60, 120].contains(minutes) else {
            return nil
        }

        if minutes == 30 {
            return rate / 2 + rate % 2
        }

        let (price, overflow) = rate.multipliedReportingOverflow(by: minutes / 60)
        return overflow ? nil : price
    }

    private func closingTime(
        on date: Date,
        hour: Int,
        timeZoneId: String
    ) -> Date? {
        guard (1...24).contains(hour),
              let timeZone = TimeZone(identifier: timeZoneId) else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(
            byAdding: .hour,
            value: hour,
            to: calendar.startOfDay(for: date)
        )
    }
}
