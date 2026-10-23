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
    var walletBalanceLKR: Int?
    var walletErrorMessage = ""
    var isLoadingWallet = false

    private let profile: UserProfile
    private let expectedSessionId: String?
    private let userRepository = UserProfileRepository()
    private let sessionRepository = ParkingSessionRepository()
    private let walletRepository = WalletRepository()
    private let notificationManager = NotificationManager.shared

    private var hasLoadedActiveSession = false
    private var pendingRequestKey = ""
    private var pendingOperationId = ""

    init(profile: UserProfile, expectedSessionId: String? = nil) {
        self.profile = profile
        self.expectedSessionId = expectedSessionId
    }

    var isBusy: Bool {
        isLoading || isLoadingSession || isStartingParking
            || isEndingParking || isExtendingParking || isLoadingWallet
    }

    var notificationMessage: String {
        notificationManager.isParkingReminderUnavailable
            ? "The expiry reminder could not be scheduled. Check Settings > Notifications > SpotShield. Parking still works."
            : ""
    }

    func availableDurations(
        zone: ParkingZone,
        at time: Date = Date()
    ) -> [Int] {
        ParkingRules.availableDurations(for: zone, at: time)
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

        return ParkingRules.price(
            hourlyRateLKR: zone.hourlyRateLKR,
            durationMinutes: selectedMinutes
        )
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
              errorMessage.isEmpty,
              walletErrorMessage.isEmpty,
              isParkedHere else {
            return false
        }

        return estimatedPrice(zone: zone, at: time) != nil
    }

    func extensionDurations(at time: Date = Date()) -> [Int] {
        guard let session = activeSession else { return [] }
        return ParkingRules.extensionDurations(for: session, at: time)
    }

    func extensionPrice(at time: Date = Date()) -> Int? {
        guard let session = activeSession,
              extensionDurations(at: time).contains(selectedExtensionMinutes) else {
            return nil
        }

        return ParkingRules.price(
            hourlyRateLKR: session.hourlyRateLKR,
            durationMinutes: selectedExtensionMinutes
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
            let currentSession = try await sessionRepository.getActiveSession(
                userId: profile.id
            )

            guard !Task.isCancelled else {
                return
            }

            _ = await notificationManager.updateParkingExpiryReminder(
                for: currentSession,
                userId: profile.id
            )

            guard !Task.isCancelled else {
                return
            }

            if let expectedSessionId,
               currentSession?.id != expectedSessionId {
                activeSession = nil
                selectedExtensionMinutes = 0
                await notificationManager.cancelParkingExpiryReminder(
                    sessionId: expectedSessionId
                )
                await LiveActivityManager.shared.end(
                    sessionId: expectedSessionId
                )
                sessionErrorMessage =
                    "This parking activity is no longer active for your account."
                hasLoadedActiveSession = true
                return
            }

            if currentSession?.id != activeSession?.id
                || currentSession?.durationMinutes != activeSession?.durationMinutes {
                selectedExtensionMinutes = 0
            }

            activeSession = currentSession

            if let currentSession {
                await LiveActivityManager.shared.start(for: currentSession)
            } else {
                await LiveActivityManager.shared.end()
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
        guard !isBusy else {
            return
        }

        await loadVehicle()
        await loadActiveSession()
        await loadWalletBalance()
    }

    func loadWalletBalance() async {
        guard !isLoadingWallet, !Task.isCancelled else { return }
        isLoadingWallet = true
        walletErrorMessage = ""
        defer { isLoadingWallet = false }
        do {
            let wallet = try await walletRepository.getWallet(userId: profile.id)
            guard !Task.isCancelled else { return }
            walletBalanceLKR = wallet?.balanceLKR ?? 0
        } catch {
            guard !Task.isCancelled else { return }
            walletErrorMessage = "Balance unavailable. Refresh to try again."
        }
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

        _ = await notificationManager.requestParkingReminderPermission()

        guard !Task.isCancelled else {
            return
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

            guard !Task.isCancelled else {
                return
            }

            guard let savedSession = try await sessionRepository.getSession(
                sessionId: sessionId,
                userId: profile.id
            ) else {
                parkingErrorMessage =
                    "Payment succeeded, but the session could not load. Try again to refresh it."
                return
            }

            guard !Task.isCancelled else {
                return
            }

            selectedExtensionMinutes = 0
            pendingRequestKey = ""
            pendingOperationId = ""

            guard savedSession.isActive else {
                activeSession = nil
                await loadActiveSession()

                guard !Task.isCancelled else {
                    return
                }

                if hasLoadedActiveSession {
                    successMessage =
                        "That earlier parking session has ended. No new charge was made."
                }

                return
            }

            activeSession = savedSession
            await LiveActivityManager.shared.start(for: savedSession)

            _ = await notificationManager.updateParkingExpiryReminder(
                for: savedSession,
                userId: profile.id
            )

            successMessage = "Parking started. LKR \(price) paid from your wallet."
            await loadWalletBalance()
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

            await notificationManager.cancelParkingExpiryReminder(
                sessionId: session.id
            )

            guard !Task.isCancelled else {
                return
            }

            await LiveActivityManager.shared.end(sessionId: session.id)

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

            var updatedSession = session
            updatedSession.durationMinutes += minutes
            updatedSession.paidUntil = session.paidUntil.addingTimeInterval(
                TimeInterval(minutes * 60)
            )
            updatedSession.totalPaidLKR += amountLKR
            activeSession = updatedSession
            selectedExtensionMinutes = 0
            pendingRequestKey = ""
            pendingOperationId = ""

            await loadActiveSession()

            guard !Task.isCancelled else {
                return
            }

            successMessage = "Parking extended. LKR \(amountLKR) paid from your wallet."
            await loadWalletBalance()
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

}
