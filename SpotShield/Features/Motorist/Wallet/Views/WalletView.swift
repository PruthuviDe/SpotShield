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
        _viewModel = State(initialValue: WalletViewModel(profile: profile))
    }

    private var isBusy: Bool {
        viewModel.isLoading || viewModel.isAddingFunds || viewModel.isUpdatingAutoDeduct
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.large) {
                if viewModel.isLoading, viewModel.wallet == nil {
                    AppLoadingView(title: "Loading your wallet…")
                }
                if !viewModel.errorMessage.isEmpty {
                    AppMessageView(title: viewModel.errorMessage, appearance: .error)
                }
                if let wallet = viewModel.wallet {
                    walletDetails(wallet)
                    AppButton(title: viewModel.isAddingFunds ? "Adding Funds…" : "Top Up LKR 1,000", systemImage: "plus", isLoading: viewModel.isAddingFunds) {
                        Task { await viewModel.addDemoFunds() }
                    }
                    .disabled(isBusy)
                    if !viewModel.successMessage.isEmpty {
                        AppMessageView(title: viewModel.successMessage, appearance: .success)
                    }
                    autoDeductSetting(wallet)
                    transactionHistory
                }
                AppButton(title: "Refresh Wallet", systemImage: "arrow.clockwise", appearance: .secondary) {
                    Task { await viewModel.loadWallet() }
                }
                .disabled(isBusy)
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.textPrimary)
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadWallet() }
        .refreshable { await viewModel.loadWallet() }
        .confirmationDialog("Enable automatic ticket payments?", isPresented: $showAutoDeductConfirmation, titleVisibility: .visible) {
            Button("Enable Auto-deduction") {
                Task { await viewModel.setTicketAutoDeduct(enabled: true) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("New LKR 1,000 tickets will be paid from your wallet when funds are available. Existing due tickets stay unchanged.")
        }
    }

    private func walletDetails(_ wallet: Wallet) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label("Available balance", systemImage: "wallet.bifold")
                .font(AppTypography.bodyBold)
            Text("LKR \(wallet.balanceLKR.formatted())")
                .font(AppTypography.timerDisplay)
                .fixedSize(horizontal: false, vertical: true)
            Text("For parking and ticket payments")
                .font(AppTypography.bodySmall)
        }
        .foregroundStyle(AppColors.textLight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.large)
        .background(AppColors.buttonBackground, in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
    }

    private func autoDeductSetting(_ wallet: Wallet) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Toggle("Automatic ticket payments", isOn: Binding(
                    get: { wallet.autoDeductEnabled },
                    set: { enabled in
                        if enabled {
                            showAutoDeductConfirmation = true
                        } else {
                            Task { await viewModel.setTicketAutoDeduct(enabled: false) }
                        }
                    }
                ))
                .font(AppTypography.bodyBold)
                .tint(AppColors.statusValid)
                .disabled(isBusy)
                Text("Applies to new tickets when your balance is sufficient. Pay existing due tickets from History.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                if viewModel.isUpdatingAutoDeduct {
                    AppLoadingView(title: "Saving your preference…")
                }
            }
        }
    }

    private var transactionHistory: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: "Recent transactions")
            if viewModel.isLoading {
                AppLoadingView(title: "Loading transactions…")
            } else if !viewModel.historyErrorMessage.isEmpty {
                AppMessageView(title: viewModel.historyErrorMessage, appearance: .error)
            } else if viewModel.transactions.isEmpty {
                AppEmptyStateView(title: "No transactions yet", message: "Your top-ups and payments will appear here.", systemImage: "creditcard")
            } else {
                ForEach(viewModel.transactions) { transaction in
                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Text(transaction.type.rawValue).font(AppTypography.bodyBold)
                            Text(transaction.createdAt, format: .dateTime.day().month().year().hour().minute())
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                            Text("\(transaction.type == .topUp ? "+" : "−") LKR \(transaction.amountLKR.formatted())")
                                .font(AppTypography.priceDisplay)
                                .foregroundStyle(transaction.type == .topUp ? AppColors.statusValid : AppColors.textPrimary)
                            Text("Balance after: LKR \(transaction.balanceAfterLKR.formatted())")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
                if viewModel.transactions.count == 50 {
                    Text("Latest 50 transactions")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }
}
