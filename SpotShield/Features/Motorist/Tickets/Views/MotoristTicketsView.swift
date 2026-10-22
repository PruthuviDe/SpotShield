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
                AppSectionHeader(title: "Your tickets", subtitle: "Review issued tickets and track wallet payments.")
                if viewModel.isLoading {
                    AppLoadingView(title: "Loading tickets…")
                } else if !viewModel.errorMessage.isEmpty {
                    AppMessageView(title: viewModel.errorMessage, appearance: .error)
                } else if viewModel.tickets.isEmpty {
                    AppEmptyStateView(title: "No tickets to show", message: "Any tickets issued to your vehicle will appear here.", systemImage: "doc.text")
                } else {
                    ForEach(viewModel.tickets) { ticket in
                        ticketCard(ticket)
                    }
                }
                AppButton(title: "Refresh Tickets", systemImage: "arrow.clockwise", appearance: .secondary) {
                    Task { await viewModel.loadTickets() }
                }
                .disabled(viewModel.isLoading || viewModel.payingTicketId != nil)
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Tickets")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadTickets() }
        .refreshable { await viewModel.loadTickets() }
        .confirmationDialog(
            "Pay LKR \(ticketToConfirm?.fineAmountLKR.formatted() ?? "0") from your wallet?",
            isPresented: Binding(
                get: { ticketToConfirm != nil },
                set: { if !$0 { ticketToConfirm = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let ticket = ticketToConfirm {
                Button("Confirm Payment") {
                    Task { await viewModel.payTicket(ticket) }
                    ticketToConfirm = nil
                }
            }
            Button("Cancel", role: .cancel) { ticketToConfirm = nil }
        } message: {
            Text("The ticket amount will be deducted from your wallet once.")
        }
    }

    private func ticketCard(_ ticket: SimulatedTicket) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppStatusBadge(title: ticket.paymentStatus.rawValue, appearance: ticket.paymentStatus == .paid ? .success : .warning)
                Text(ticket.zoneName).font(AppTypography.titleMedium)
                Label(ticket.licensePlate, systemImage: "car").font(AppTypography.bodyBold)
                Text("LKR \(ticket.fineAmountLKR.formatted())").font(AppTypography.priceDisplay)
                Text(ticket.reason)
                Text(ticket.issuedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text("Ticket ID: \(ticket.id)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .textSelection(.enabled)
                if let message = ticket.paymentMessage, !message.isEmpty {
                    Text(message.replacingOccurrences(of: "demo wallet", with: "wallet"))
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                }
                if ticket.paymentStatus == .due {
                    AppButton(
                        title: viewModel.payingTicketId == ticket.id ? "Paying…" : "Pay LKR \(ticket.fineAmountLKR.formatted())",
                        systemImage: "wallet.bifold",
                        isLoading: viewModel.payingTicketId == ticket.id
                    ) {
                        ticketToConfirm = ticket
                    }
                    .disabled(viewModel.payingTicketId != nil || viewModel.isLoading)
                }
                if let message = viewModel.paymentErrors[ticket.id] {
                    AppMessageView(title: message, appearance: .error)
                }
            }
        }
    }
}
