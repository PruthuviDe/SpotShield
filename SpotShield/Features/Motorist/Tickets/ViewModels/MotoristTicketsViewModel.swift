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
    var payingTicketId: String?
    var errorMessage = ""
    var paymentErrors: [String: String] = [:]
    private let repository = TicketRepository()

    func loadTickets() async {
        guard !isLoading, payingTicketId == nil else { return }
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }
        do {
            tickets = try await repository.getMyTickets()
        } catch {
            errorMessage = "Could not load your tickets. Please refresh."
        }
    }

    func payTicket(_ ticket: SimulatedTicket) async {
        guard !isLoading, payingTicketId == nil,
              ticket.paymentStatus == .due else { return }

        payingTicketId = ticket.id
        paymentErrors[ticket.id] = nil
        defer { payingTicketId = nil }

        do {
            try await repository.payTicket(ticketId: ticket.id)
            guard let index = tickets.firstIndex(where: { $0.id == ticket.id }) else { return }
            tickets[index].paymentStatus = .paid
            tickets[index].paymentMessage = "Paid from your demo wallet."
        } catch {
            paymentErrors[ticket.id] = "Payment was not confirmed. Check your wallet balance, then refresh or safely retry."
        }
    }
}
