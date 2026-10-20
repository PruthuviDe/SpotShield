//
//  MotoristTicketsView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import SwiftUI

struct MotoristTicketsView: View {
    @State private var viewModel = MotoristTicketsViewModel()
    @State private var ticketToConfirm: SimulatedTicket?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.large) {
                Text("These tickets are simulations. No real fines or payments are involved.")
                    .foregroundStyle(AppColors.textSecondary)
                if viewModel.isLoading {
                    ProgressView("Loading tickets...")
                } else if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage).foregroundStyle(AppColors.statusOverstay)
                } else if viewModel.tickets.isEmpty {
                    Text("You have no demo tickets.")
                } else {
                    ForEach(viewModel.tickets) { ticket in
                        VStack(alignment: .leading, spacing: AppSpacing.medium) {
                            Text(ticket.zoneName).font(AppTypography.titleSmall)
                            Text(ticket.licensePlate).font(AppTypography.bodyBold)
                            Text("LKR \(ticket.fineAmountLKR) • \(ticket.paymentStatus.rawValue)")
                            Text(ticket.reason)
                            Text(ticket.issuedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(AppTypography.caption)
                            Text("Ticket: \(ticket.id)").font(AppTypography.caption)
                            if let paymentMessage = ticket.paymentMessage, !paymentMessage.isEmpty {
                                Text(paymentMessage)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            if ticket.paymentStatus == .due {
                                Button("Pay LKR \(ticket.fineAmountLKR) from wallet") {
                                    ticketToConfirm = ticket
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.payingTicketId != nil)
                            }
                            if viewModel.payingTicketId == ticket.id {
                                ProgressView("Paying demo ticket...")
                            }
                            if let message = viewModel.paymentErrors[ticket.id] {
                                Text(message).foregroundStyle(AppColors.statusOverstay)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.medium)
                        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
                    }
                }
                Button("Refresh") { Task { await viewModel.loadTickets() } }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLoading)
            }
            .padding(AppSpacing.large)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("My Demo Tickets")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadTickets() }
        .confirmationDialog(
            "Pay LKR \(ticketToConfirm?.fineAmountLKR ?? 0) from your demo wallet?",
            isPresented: Binding(
                get: { ticketToConfirm != nil },
                set: { if !$0 { ticketToConfirm = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let ticket = ticketToConfirm {
                Button("Confirm demo payment") {
                    Task { await viewModel.payTicket(ticket) }
                    ticketToConfirm = nil
                }
            }
            Button("Cancel", role: .cancel) { ticketToConfirm = nil }
        } message: {
            Text("This will deduct the ticket amount once from your demo wallet. No real money is involved.")
        }
    }
}
