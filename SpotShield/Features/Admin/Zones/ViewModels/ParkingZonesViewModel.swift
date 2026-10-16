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
    var isLoading = false
    var errorMessage = ""

    private let repository = ParkingZoneRepository()

    func loadZones() async {
        guard !isLoading else { return }

        errorMessage = ""
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            zones = try await repository.getZones()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
