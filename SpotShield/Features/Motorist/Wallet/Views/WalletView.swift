//
//  WalletView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-18.
//

import SwiftUI

struct WalletView: View {
    @State private var viewModel: WalletViewModel
    @State private var showAutoDeductConfirmation = false

    init(profile: UserProfile) {
        _viewModel = State(
            initialValue: WalletViewModel(profile: profile)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if viewModel.isLoading, viewModel.wallet == nil {
                    ProgressView("Loading your wallet...")
                }

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundStyle(AppColors.statusOverstay)
                }

                if let wallet = viewModel.wallet {
                    walletDetails(wallet: wallet)
                    autoDeductSetting(wallet: wallet)

                    Button {
                        Task {
                            await viewModel.addDemoFunds()
                        }
                    } label: {
                        HStack(spacing: AppSpacing.small) {
                            if viewModel.isAddingFunds {
                                ProgressView()
                                    .tint(AppColors.accent)
                            }

                            Text(
                                viewModel.isAddingFunds
                                    ? "Adding demo funds..."
                                    : "Add LKR 1,000 Demo Funds"
                            )
                            .font(AppTypography.bodyBold)
                        }
                        .foregroundStyle(AppColors.accent)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(AppColors.buttonBackground, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isAddingFunds || viewModel.isLoading || viewModel.isUpdatingAutoDeduct)

                    if !viewModel.successMessage.isEmpty {
                        Text(viewModel.successMessage)
                            .foregroundStyle(AppColors.statusValid)
                    }

                    transactionHistory
                }

                Button("Refresh") {
                    Task {
                        await viewModel.loadWallet()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading || viewModel.isAddingFunds || viewModel.isUpdatingAutoDeduct)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.large)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.textPrimary)
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadWallet()
        }
        .confirmationDialog(
            "Enable auto-deduction for new demo tickets?",
            isPresented: $showAutoDeductConfirmation,
            titleVisibility: .visible
        ) {
            Button("Enable auto-deduction") {
                Task { await viewModel.setTicketAutoDeduct(enabled: true) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("New LKR 1,000 demo tickets will be paid from your wallet when possible. Existing due tickets will not be charged. Tickets stay due if your balance is too low.")
        }
    }

    private func walletDetails(wallet: Wallet) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Demo balance")
                .font(AppTypography.titleSmall)

            Text("LKR \(wallet.balanceLKR)")
                .font(AppTypography.priceDisplay)

            Text("These are demo funds. No real money is involved.")
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(
            AppColors.card,
            in: RoundedRectangle(
                cornerRadius: AppSpacing.radiusCard
            )
        )
    }

    private func autoDeductSetting(wallet: Wallet) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Toggle(
                "Auto-deduct new demo tickets",
                isOn: Binding(
                    get: { wallet.autoDeductEnabled },
                    set: { enabled in
                        if enabled {
                            showAutoDeductConfirmation = true
                        } else {
                            Task { await viewModel.setTicketAutoDeduct(enabled: false) }
                        }
                    }
                )
            )
            .disabled(viewModel.isLoading || viewModel.isAddingFunds || viewModel.isUpdatingAutoDeduct)

            Text("This only applies to tickets issued after you enable it. You can pay older due tickets manually.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
    }

    private var transactionHistory: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Recent transactions")
                .font(AppTypography.titleSmall)

            if viewModel.isLoading {
                ProgressView("Loading transactions...")
            } else if !viewModel.historyErrorMessage.isEmpty {
                Text(viewModel.historyErrorMessage)
                    .foregroundStyle(AppColors.statusOverstay)
            } else if viewModel.transactions.isEmpty {
                Text("No transactions yet.")
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                ForEach(viewModel.transactions) { transaction in
                    transactionDetails(transaction: transaction)
                }

                if viewModel.transactions.count == 50 {
                    Text("Showing the latest 50 transactions.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func transactionDetails(
        transaction: WalletTransaction
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(transaction.type.rawValue)
                .font(AppTypography.bodyBold)

            Text(
                transaction.createdAt,
                format: .dateTime.day().month().year().hour().minute()
            )
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textSecondary)

            if transaction.type == .topUp {
                Text("+ LKR \(transaction.amountLKR)")
                    .font(AppTypography.priceDisplay)
                    .foregroundStyle(AppColors.statusValid)
            } else {
                Text("- LKR \(transaction.amountLKR)")
                    .font(AppTypography.priceDisplay)
            }

            Text("Balance after: LKR \(transaction.balanceAfterLKR)")
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(
            AppColors.card,
            in: RoundedRectangle(
                cornerRadius: AppSpacing.radiusCard
            )
        )
    }
}
