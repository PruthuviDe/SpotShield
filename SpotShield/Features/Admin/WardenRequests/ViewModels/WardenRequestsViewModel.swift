//
//  WardenRequestsViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import Foundation
import Observation

@MainActor
@Observable
final class WardenRequestsViewModel {
    var requests: [WardenRequest] = []
    var isLoading = false
    var errorMessage = ""
    var successMessage = ""

    private let repository = WardenRequestRepository()

    func loadRequests() async {
        guard !isLoading else { return }

        errorMessage = ""
        successMessage = ""
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            requests = try await repository.getWaitingRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func approveRequest(
        request: WardenRequest,
        adminUserId: String
    ) async {
        guard !isLoading else { return }

        errorMessage = ""
        successMessage = ""
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            try await repository.approveRequest(
                request: request,
                adminUserId: adminUserId
            )

            requests.removeAll { savedRequest in
                savedRequest.id == request.id
            }
            successMessage = "Warden access approved for \(request.name)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectRequest(
        request: WardenRequest,
        adminUserId: String
    ) async {
        guard !isLoading else { return }

        errorMessage = ""
        successMessage = ""
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            try await repository.rejectRequest(
                userId: request.id,
                adminUserId: adminUserId
            )

            requests.removeAll { savedRequest in
                savedRequest.id == request.id
            }
            successMessage = "Application rejected for \(request.name)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
