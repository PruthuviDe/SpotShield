//
//  ParkingHistoryViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import Foundation
import Observation

@MainActor
@Observable
final class ParkingHistoryViewModel {
    var sessions: [ParkingSession] = []
    var isLoading = false
    var errorMessage = ""

    private let profile: UserProfile
    private let repository = ParkingSessionRepository()

    init(profile: UserProfile) {
        self.profile = profile
    }

    func loadHistory() async {
        guard !isLoading, !Task.isCancelled else {
            return
        }

        errorMessage = ""

        guard profile.role == .motorist else {
            errorMessage = "Parking history is available to Drivers only."
            return
        }

        isLoading = true

        defer {
            isLoading = false
        }

        do {
            let savedSessions = try await repository.getHistory(
                userId: profile.id
            )

            guard !Task.isCancelled else {
                return
            }

            sessions = savedSessions
        } catch {
            guard !Task.isCancelled else {
                return
            }

            errorMessage =
                "Could not load your parking history. Please try again."
        }
    }
}
