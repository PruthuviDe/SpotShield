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
    var isLoadingVehicle = false
    var assignedZones: [WardenPatrolZone] = []
    var isLoadingZones = false
    var assignmentError = ""
    var notificationStatus = "Checking..."
    var notificationError = ""
    var isRequestingNotifications = false

    init(profile: UserProfile) {
        self.profile = profile
    }

    func load() async {
        await refreshNotificationStatus()

        switch profile.role {
        case .motorist:
            await loadVehicle()
        case .warden:
            await loadAssignedZones()
        case .admin:
            break
        }
    }

    func loadVehicle() async {
        guard profile.role == .motorist, !isLoadingVehicle else {
            return
        }

        vehicle = nil
        vehicleMessage = ""

        guard let vehicleId = profile.primaryVehicleId else {
            vehicleMessage = "No vehicle is linked to this account."
            return
        }

        isLoadingVehicle = true
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
            }
        } catch {
            guard !Task.isCancelled else { return }
            vehicleMessage = "Could not load vehicle details."
        }
    }

    func loadAssignedZones() async {
        guard profile.role == .warden, !isLoadingZones else { return }

        isLoadingZones = true
        assignmentError = ""
        assignedZones = []
        defer { isLoadingZones = false }

        do {
            let zones = try await wardenRepository.getZones()
            guard !Task.isCancelled else { return }
            assignedZones = zones.sorted { $0.name < $1.name }
        } catch {
            guard !Task.isCancelled else { return }
            assignmentError = "Could not load your assigned zones. Please refresh."
        }
    }

    func refreshNotificationStatus() async {
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
