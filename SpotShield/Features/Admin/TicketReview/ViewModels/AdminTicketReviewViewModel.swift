//
//  AdminTicketReviewViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminTicketReviewViewModel {
    var observations: [WardenObservation] = []
    var showReviewed = false
    var isLoading = false
    var reviewingId = ""
    var errorMessage = ""
    var successMessage = ""
    var selectedObservation: WardenObservation?
    var issueTicket = false
    var decisionReason = ""
    var reviewDetails: ObservationReview?
    var isCheckingReview = false
    var reviewErrorMessage = ""

    private let repository = WardenObservationRepository()

    var canConfirmDecision: Bool {
        !isCheckingReview && reviewingId.isEmpty
            && !decisionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && decisionReason.count <= 200
            && (!issueTicket || reviewDetails?.canIssueTicket == true)
    }

    func loadObservations() async {
        guard !isLoading, reviewingId.isEmpty else { return }
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }
        do {
            if showReviewed {
                observations = try await repository.getReviewedObservations()
            } else {
                observations = try await repository.getPendingObservations()
            }
        } catch {
            errorMessage = "Could not load observations. Please refresh."
        }
    }

    func prepareReview(_ observation: WardenObservation, issueTicket: Bool) {
        self.issueTicket = issueTicket
        decisionReason = ""
        if issueTicket {
            decisionReason = observation.notes ?? ""
            if decisionReason.isEmpty { decisionReason = observation.parkingStatus }
        }
        reviewDetails = nil
        reviewErrorMessage = ""
        selectedObservation = observation
    }

    func loadReview(id: String) async {
        isCheckingReview = true
        defer { isCheckingReview = false }
        do {
            let details = try await repository.getReview(id: id)
            guard selectedObservation?.id == id else { return }
            reviewDetails = details
        } catch {
            reviewErrorMessage = "Could not verify the current case. You can retry or dismiss with a reason."
        }
    }

    func confirmDecision() async {
        guard canConfirmDecision, let observation = selectedObservation else { return }
        reviewingId = observation.id
        errorMessage = ""
        successMessage = ""
        reviewErrorMessage = ""
        defer { reviewingId = "" }
        do {
            try await repository.reviewObservation(id: observation.id, issueTicket: issueTicket, reason: decisionReason)
            successMessage = issueTicket ? "Demo ticket issued." : "Observation dismissed."
            observations.removeAll { $0.id == observation.id }
            selectedObservation = nil
        } catch {
            reviewErrorMessage = error.localizedDescription
            if issueTicket {
                await loadReview(id: observation.id)
            }
        }
    }
}
