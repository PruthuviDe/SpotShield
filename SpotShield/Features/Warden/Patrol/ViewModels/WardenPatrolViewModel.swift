//
//  WardenPatrolViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import Foundation
import Observation

@MainActor
@Observable
final class WardenPatrolViewModel {
    var zones: [WardenPatrolZone] = []
    var selectedZoneId = "" { didSet { resetPlateCheck() } }
    var licensePlate = "" { didSet { resetPlateCheck() } }
    var notes = ""
    var isConfirmed = false
    var checkResult: PlateCheckResult?
    var pendingSubmission: ObservationSubmission?
    var isLoading = false
    var errorMessage = ""
    var successMessage = ""

    private let repository = WardenObservationRepository()

    private func resetPlateCheck() {
        checkResult = nil
        isConfirmed = false
        successMessage = ""
        errorMessage = ""
    }

    func loadZones() async {
        guard !isLoading else { return }
        pendingSubmission = repository.pendingSubmission()
        isLoading = true
        errorMessage = ""
        successMessage = ""
        defer { isLoading = false }
        do {
            zones = try await repository.getZones()
            if !zones.contains(where: { $0.id == selectedZoneId }) {
                selectedZoneId = zones.first?.id ?? ""
            }
        } catch {
            errorMessage = "Could not load your assigned zones. Please refresh."
        }
    }

    func checkPlate() async {
        guard !isLoading, pendingSubmission == nil, isConfirmed else { return }
        isLoading = true
        errorMessage = ""
        successMessage = ""
        checkResult = nil
        defer { isLoading = false }
        do {
            checkResult = try await repository.checkPlate(zoneId: selectedZoneId, licensePlate: licensePlate)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitObservation() async {
        guard !isLoading, pendingSubmission == nil,
              isConfirmed, checkResult?.status.canReport == true else { return }
        isLoading = true
        errorMessage = ""
        successMessage = ""
        defer { isLoading = false }
        do {
            try await repository.submitObservation(zoneId: selectedZoneId, licensePlate: licensePlate, notes: notes)
            finishSubmission()
        } catch {
            pendingSubmission = repository.pendingSubmission()
            checkResult = nil
            errorMessage = error.localizedDescription
        }
    }

    func retrySubmission() async {
        guard !isLoading, pendingSubmission != nil else { return }
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }
        do {
            try await repository.retryPendingSubmission()
            finishSubmission()
        } catch {
            pendingSubmission = repository.pendingSubmission()
            errorMessage = error.localizedDescription
        }
    }

    private func finishSubmission() {
        licensePlate = ""
        notes = ""
        checkResult = nil
        pendingSubmission = nil
        successMessage = "Observation submitted — awaiting Administrator review."
    }
}
