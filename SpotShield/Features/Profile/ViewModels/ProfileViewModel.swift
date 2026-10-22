//
//  ProfileViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class ProfileViewModel {
    let profile: UserProfile

    private let repository = UserProfileRepository()
    private let wardenRepository = WardenObservationRepository()
    private let notificationCenter = UNUserNotificationCenter.current()

    var vehicle: Vehicle?
    var vehicleMessage = ""
    var vehicleError = ""
    var isLoadingVehicle = false
    var assignedZones: [WardenPatrolZone] = []
    var isLoadingZones = false
    var assignmentError = ""
    var notificationStatus = "Checking..."
    var notificationError = ""
    var isRefreshingNotificationStatus = false
    var isRequestingNotifications = false
    var isBiometricEnabled = false
    var biometricDeviceName = "Biometric unlock"
    var isBiometricAvailable = false
    var isUpdatingBiometric = false
    var biometricError = ""

    init(profile: UserProfile) {
        self.profile = profile
    }

    func load() async {
        await refreshNotificationStatus()
        refreshBiometricStatus()

        switch profile.role {
        case .motorist:
            await loadVehicle()
        case .warden:
            await loadAssignedZones()
        case .admin:
            break
        }
    }

    func refreshBiometricStatus() {
        let manager = BiometricManager.shared
        biometricDeviceName = manager.deviceName()
        isBiometricAvailable = manager.isAvailable()
        isBiometricEnabled = manager.isEnabled(for: profile.id)
    }

    func setBiometricEnabled(_ isEnabled: Bool) async {
        guard !isUpdatingBiometric else { return }

        biometricError = ""
        isUpdatingBiometric = true
        defer { isUpdatingBiometric = false }

        if isEnabled {
            do {
                try await BiometricManager.shared.enable(for: profile.id)
                isBiometricEnabled = true
            } catch {
                biometricError = BiometricManager.shared.errorMessage(for: error)
                isBiometricEnabled = false
            }
        } else {
            BiometricManager.shared.disable(for: profile.id)
            isBiometricEnabled = false
        }
    }

    func loadVehicle() async {
        guard profile.role == .motorist, !isLoadingVehicle else {
            return
        }

        guard let vehicleId = profile.primaryVehicleId else {
            vehicle = nil
            vehicleMessage = "No vehicle is linked to this account."
            vehicleError = ""
            return
        }

        isLoadingVehicle = true
        vehicleError = ""
        defer { isLoadingVehicle = false }

        do {
            let loadedVehicle = try await repository.getVehicle(
                vehicleId: vehicleId
            )

            guard !Task.isCancelled else { return }

            if let loadedVehicle, loadedVehicle.ownerUserId == profile.id {
                vehicle = loadedVehicle
                vehicleMessage = ""
            } else {
                vehicleMessage = "Vehicle details could not be found."
                vehicleError = vehicleMessage
            }
        } catch {
            guard !Task.isCancelled else { return }
            vehicleMessage = "Could not load vehicle details."
            vehicleError = vehicleMessage
        }
    }

    func loadAssignedZones() async {
        guard profile.role == .warden, !isLoadingZones else { return }

        isLoadingZones = true
        assignmentError = ""
        defer { isLoadingZones = false }

        do {
            let zones = try await wardenRepository.getZones()
            guard !Task.isCancelled else { return }
            assignedZones = zones.sorted { $0.name < $1.name }
        } catch {
            guard !Task.isCancelled else { return }
            assignmentError = "Could not load your assigned zones. Try again."
        }
    }

    func refreshNotificationStatus() async {
        guard !isRefreshingNotificationStatus else { return }

        isRefreshingNotificationStatus = true
        defer { isRefreshingNotificationStatus = false }
        notificationStatus = "Checking..."
        let settings = await notificationCenter.notificationSettings()
        guard !Task.isCancelled else { return }

        switch settings.authorizationStatus {
        case .authorized:
            notificationStatus = "Allowed"
        case .provisional:
            notificationStatus = "Allowed quietly"
        case .ephemeral:
            notificationStatus = "Temporary access"
        case .denied:
            notificationStatus = "Off"
        case .notDetermined:
            notificationStatus = "Not requested"
        @unknown default:
            notificationStatus = "Unavailable"
        }
    }

    func requestNotifications() async {
        guard !isRequestingNotifications else { return }

        isRequestingNotifications = true
        notificationError = ""
        defer { isRequestingNotifications = false }

        do {
            _ = try await notificationCenter.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
        } catch {
            notificationError = "Could not request notification access."
        }

        await refreshNotificationStatus()
    }
}
