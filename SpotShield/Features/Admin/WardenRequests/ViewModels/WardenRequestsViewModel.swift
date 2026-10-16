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

    private let repository = WardenRequestRepository()

    func loadRequests() async {
        guard !isLoading else { return }

        errorMessage = ""
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
