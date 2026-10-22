//
//  WardenRecordsViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import Foundation
import Observation

@MainActor
@Observable
final class WardenRecordsViewModel {
    var observations: [WardenObservation] = []
    var isLoading = false
    var errorMessage = ""

    private let repository = WardenObservationRepository()

    func loadObservations() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = ""

        defer { isLoading = false }

        do {
            observations = try await repository.getWardenObservations()
        } catch {
            errorMessage = "Could not load your observations. Try again."
        }
    }
}
