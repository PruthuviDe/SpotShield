//
//  ParkingZonesViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import Foundation
import Observation

@MainActor
@Observable
final class ParkingZonesViewModel {
    var zones: [ParkingZone] = []
    var assignments: [WardenAssignment] = []
    var wardens: [UserProfile] = []

    var isLoading = false
    var errorMessage = ""
    var successMessage = ""

    private let repository = ParkingZoneRepository()
    private let assignmentRepository = WardenAssignmentRepository()
    private let userRepository = UserProfileRepository()

    func loadZones() async {
        guard !isLoading else { return }

        errorMessage = ""
        successMessage = ""
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            try await loadSavedData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func publishZone(
        zone: ParkingZone,
        assignmentId: String
    ) async {
        guard !isLoading else { return }

        errorMessage = ""
        successMessage = ""

        guard !assignmentId.isEmpty else {
            errorMessage = "Please choose a Warden assignment."
            return
        }

        isLoading = true

        defer {
            isLoading = false
        }

        do {
            try await loadSavedData()

            guard let currentZone = zones.first(where: {
                $0.id == zone.id
            }) else {
                errorMessage = "This parking zone could not be found."
                return
            }

            if currentZone.isActive {
                successMessage = "This zone is already active."
                return
            }

            guard currentZone.policyVersion == zone.policyVersion else {
                errorMessage = "This zone changed. Review the updated details and try again."
                return
            }

            guard let assignment = assignments.first(where: {
                $0.id == assignmentId
                    && $0.parkingZoneId == currentZone.id
                    && $0.isActive
                    && $0.endedAt == nil
            }) else {
                errorMessage = "Choose an active assignment for this zone."
                return
            }

            guard wardens.contains(where: {
                $0.id == assignment.wardenUserId
            }) else {
                errorMessage = "This Warden is no longer available. Choose another assignment."
                return
            }

            let savedZone = try await repository.publishZone(
                zone: currentZone,
                assignment: assignment
            )

            updateZoneInList(zone: savedZone)
            successMessage = "The zone is now published and active."
        } catch {
            errorMessage = error.localizedDescription
                + " Refresh the list before trying again."
        }
    }

    func deactivateZone(zone: ParkingZone) async {
        guard !isLoading else { return }

        errorMessage = ""
        successMessage = ""
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            zones = try await repository.getZones()

            guard let currentZone = zones.first(where: {
                $0.id == zone.id
            }) else {
                errorMessage = "This parking zone could not be found."
                return
            }

            if !currentZone.isActive {
                successMessage = "This zone is already inactive."
                return
            }

            guard currentZone.policyVersion == zone.policyVersion else {
                errorMessage = "This zone changed. Review the updated details and try again."
                return
            }

            let savedZone = try await repository.deactivateZone(
                zone: currentZone
            )

            updateZoneInList(zone: savedZone)
            successMessage = "The zone is now inactive."
        } catch {
            errorMessage = error.localizedDescription
                + " Refresh the list before trying again."
        }
    }

    func activeAssignments(zoneId: String) -> [WardenAssignment] {
        return assignments.filter { assignment in
            assignment.parkingZoneId == zoneId
                && assignment.isActive
                && assignment.endedAt == nil
        }
    }

    func wardenName(userId: String) -> String {
        return wardens.first {
            $0.id == userId
        }?.name ?? userId
    }

    private func loadSavedData() async throws {
        let savedZones = try await repository.getZones()
        let savedAssignments = try await assignmentRepository.getAssignments()
        let savedWardens = try await userRepository.getWardens()

        zones = savedZones
        assignments = savedAssignments
        wardens = savedWardens
    }

    private func updateZoneInList(zone: ParkingZone) {
        if let index = zones.firstIndex(where: {
            $0.id == zone.id
        }) {
            zones[index] = zone
        }
    }
}
