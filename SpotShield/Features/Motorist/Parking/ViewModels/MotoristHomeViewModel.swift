//
//  MotoristHomeViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-22.
//

import Foundation
import Observation

@MainActor
@Observable
final class MotoristHomeViewModel {
    var session: ParkingSession?
    var isLoading = false
    var errorMessage = ""

    private let repository = ParkingSessionRepository()

    func loadSession(userId: String) async {
        guard !isLoading, !Task.isCancelled else { return }
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }

        do {
            let savedSession = try await repository.getActiveSession(userId: userId)
            guard !Task.isCancelled else { return }
            session = savedSession
            _ = await NotificationManager.shared.updateParkingExpiryReminder(
                for: savedSession,
                userId: userId
            )
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "Could not load your parking. Try again."
        }
    }
}
