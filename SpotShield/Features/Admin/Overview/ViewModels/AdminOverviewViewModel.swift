//
//  AdminOverviewViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminOverviewViewModel {
    let profile: UserProfile

    var activeZoneCount = 0
    var pendingApplicationCount = 0
    var pendingObservationCount = 0
    var isLoading = false
    var errorMessage = ""
    var lastUpdated: Date?

    private let zoneRepository = ParkingZoneRepository()
    private let requestRepository = WardenRequestRepository()
    private let observationRepository = WardenObservationRepository()

    init(profile: UserProfile) {
        self.profile = profile
    }

    func loadOverview() async {
        guard !isLoading else { return }

        errorMessage = ""
        lastUpdated = nil

        guard profile.role == .admin else {
            errorMessage = "This overview is available to Admin accounts only."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let zones = try await zoneRepository.getZones()
            guard !Task.isCancelled else { return }

            let applications = try await requestRepository.getWaitingRequests()
            guard !Task.isCancelled else { return }

            let observations = try await observationRepository.getPendingObservationCount()
            guard !Task.isCancelled else { return }

            activeZoneCount = zones.filter { $0.isPublished && $0.isActive }.count
            pendingApplicationCount = applications.count
            pendingObservationCount = observations
            lastUpdated = Date()
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "Could not load the overview. Check your connection and try again."
        }
    }
}
