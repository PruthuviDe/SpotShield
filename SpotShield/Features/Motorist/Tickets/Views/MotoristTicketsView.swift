//
//  MotoristTicketsView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import SwiftUI

struct MotoristTicketsView: View {
    @State private var viewModel = MotoristTicketsViewModel()

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
                            Text("Wallet auto-deduction is not enabled in this version. This ticket remains due.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
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
    }
}
