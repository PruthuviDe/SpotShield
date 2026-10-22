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
                if viewModel.isLoading && viewModel.tickets.isEmpty {
                    AppLoadingView(title: "Loading tickets…")
                }
                if !viewModel.errorMessage.isEmpty {
                    AppMessageView(
                        title: viewModel.errorMessage,
                        appearance: .error,
                        actionTitle: "Try Again",
                        action: { Task { await viewModel.loadTickets() } }
                    )
                }
                if !viewModel.isLoading && viewModel.tickets.isEmpty && viewModel.errorMessage.isEmpty {
                    AppEmptyStateView(title: "No tickets to show", message: "Any tickets issued to your vehicle will appear here.", systemImage: "doc.text")
                }
                if !viewModel.tickets.isEmpty {
                    if viewModel.isLoading {
                        ProgressView("Updating tickets…")
                            .font(AppTypography.bodySmall)
                    }
                    ForEach(viewModel.tickets) { ticket in
                        ticketCard(ticket)
                    }
                }
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Tickets")
        .navigationBarTitleDisplayMode(.inline)
        .refreshOnAppearAndForeground { await viewModel.loadTickets() }
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
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                HStack(alignment: .top) {
                    AppStatusBadge(title: ticket.paymentStatus.rawValue, appearance: ticketStatusAppearance(ticket.paymentStatus))
                    Spacer(minLength: AppSpacing.small)
                    Text(ticket.issuedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.trailing)
                }
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text(ticket.zoneName)
                        .font(AppTypography.titleMedium)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(ticket.licensePlate, systemImage: "car")
                        .font(AppTypography.bodyBold)
                }
                Divider()
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text("Reason")
                        .font(AppTypography.captionBold)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(ticket.reason)
                        .font(AppTypography.bodyMedium)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Fine amount")
                            .font(AppTypography.bodyBold)
                            .foregroundStyle(AppColors.textLight)
                        Spacer(minLength: AppSpacing.small)
                        Text("LKR \(ticket.fineAmountLKR.formatted())")
                            .font(AppTypography.priceDisplay)
                            .foregroundStyle(AppColors.accent)
                            .fixedSize()
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text("Fine amount")
                            .font(AppTypography.bodyBold)
                            .foregroundStyle(AppColors.textLight)
                        Text("LKR \(ticket.fineAmountLKR.formatted())")
                            .font(AppTypography.priceDisplay)
                            .foregroundStyle(AppColors.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(AppSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.buttonBackground, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text("Ticket ID")
                        .font(AppTypography.captionBold)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(ticket.id)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
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

    private func ticketStatusAppearance(_ status: TicketStatus) -> AppStatusAppearance {
        switch status {
        case .paid: .success
        case .due: .warning
        case .pending: .neutral
        }
    }
}
