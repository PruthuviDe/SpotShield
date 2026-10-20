//
//  MotoristTicketsViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import Foundation
import Observation

@MainActor
@Observable
final class MotoristTicketsViewModel {
    var tickets: [SimulatedTicket] = []
    var isLoading = false
    var errorMessage = ""
    private let repository = TicketRepository()

    func loadTickets() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }
        do {
            tickets = try await repository.getMyTickets()
        } catch {
            errorMessage = "Could not load your tickets. Please refresh."
        }
    }
}
