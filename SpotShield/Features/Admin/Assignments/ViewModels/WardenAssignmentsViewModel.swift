//
//  WardenAssignmentsViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import Foundation
import Observation

@MainActor
@Observable
final class WardenAssignmentsViewModel {
    var zones: [ParkingZone] = []
    var wardens: [UserProfile] = []
    var assignments: [WardenAssignment] = []

    var selectedZoneId = ""
    var selectedWardenId = ""

    var isLoading = false
    var errorMessage = ""
    var successMessage = ""

    private let zoneRepository = ParkingZoneRepository()
    private let userRepository = UserProfileRepository()
    private let assignmentRepository = WardenAssignmentRepository()

    private var newAssignmentId = UUID().uuidString

    func loadData() async {
        guard !isLoading else { return }

        errorMessage = ""
        successMessage = ""
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            let savedZones = try await zoneRepository.getZones()
            let savedWardens = try await userRepository.getWardens()
            let savedAssignments = try await assignmentRepository.getAssignments()

            zones = savedZones
            wardens = savedWardens
            assignments = savedAssignments
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createAssignment(adminUserId: String) async {
        guard !isLoading else { return }

        errorMessage = ""
        successMessage = ""

        let zoneId = selectedZoneId
        let wardenId = selectedWardenId

        guard zones.contains(where: { $0.id == zoneId }),
              wardens.contains(where: { $0.id == wardenId }) else {
            errorMessage = "Please choose a parking zone and a Warden."
            return
        }

        isLoading = true

        defer {
            isLoading = false
        }

        do {
            assignments = try await assignmentRepository.getAssignments()

            if assignments.contains(where: { $0.id == newAssignmentId }) {
                resetSelection()
                successMessage = "Your earlier assignment was saved. Check its status below."
                return
            }

            let alreadyAssigned = assignments.contains { assignment in
                assignment.isActive
                    && assignment.parkingZoneId == zoneId
                    && assignment.wardenUserId == wardenId
            }

            guard !alreadyAssigned else {
                errorMessage = "This Warden already has an active assignment for this zone."
                return
            }

            try await assignmentRepository.createAssignment(
                assignmentId: newAssignmentId,
                parkingZoneId: zoneId,
                wardenUserId: wardenId,
                adminUserId: adminUserId
            )

            resetSelection()
            successMessage = "Warden assigned successfully."

            await refreshAssignmentsAfterSave()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func endAssignment(assignment: WardenAssignment) async {
        guard !isLoading else { return }

        errorMessage = ""
        successMessage = ""
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            assignments = try await assignmentRepository.getAssignments()

            guard let currentAssignment = assignments.first(where: {
                $0.id == assignment.id
            }) else {
                errorMessage = "This assignment could not be found."
                return
            }

            guard currentAssignment.isActive else {
                successMessage = "This assignment has already ended."
                return
            }

            try await assignmentRepository.endAssignment(
                assignmentId: assignment.id
            )

            successMessage = "Assignment ended successfully."

            await refreshAssignmentsAfterSave()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetSelection() {
        selectedZoneId = ""
        selectedWardenId = ""
        newAssignmentId = UUID().uuidString
    }

    
    private func refreshAssignmentsAfterSave() async {
        do {
            assignments = try await assignmentRepository.getAssignments()
        } catch {
            errorMessage = "The change was saved, but the list could not update. Try again."
        }
    }
}
