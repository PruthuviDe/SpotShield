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
    private let notificationCenter = UNUserNotificationCenter.current()

    var vehicle: Vehicle?
    var vehicleMessage = ""
    var isLoadingVehicle = false
    var notificationStatus = "Checking..."
    var notificationError = ""
    var isRequestingNotifications = false

    init(profile: UserProfile) {
        self.profile = profile
    }

    func load() async {
        await loadVehicle()
        await refreshNotificationStatus()
    }

    func loadVehicle() async {
        guard profile.role == .motorist else {
            return
        }

        guard let vehicleId = profile.primaryVehicleId else {
            vehicleMessage = "No vehicle is linked to this account."
            return
        }

        isLoadingVehicle = true

        do {
            let loadedVehicle = try await repository.getVehicle(
                vehicleId: vehicleId
            )

            if let loadedVehicle, loadedVehicle.ownerUserId == profile.id {
                vehicle = loadedVehicle
                vehicleMessage = ""
            } else {
                vehicleMessage = "Vehicle details could not be found."
            }
        } catch {
            vehicleMessage = "Could not load vehicle details."
        }

        isLoadingVehicle = false
    }

    func refreshNotificationStatus() async {
        notificationStatus = "Checking..."
        let settings = await notificationCenter.notificationSettings()

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
        isRequestingNotifications = true
        notificationError = ""

        do {
            _ = try await notificationCenter.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
        } catch {
            notificationError = "Could not request notification access."
        }

        await refreshNotificationStatus()
        isRequestingNotifications = false
    }
}
