//
//  WalletView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-18.
//

import SwiftUI

struct WalletView: View {
    @State private var viewModel: WalletViewModel

    init(profile: UserProfile) {
        _viewModel = State(
            initialValue: WalletViewModel(profile: profile)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if viewModel.isLoading {
                    ProgressView("Loading your wallet...")
                }

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundStyle(AppColors.statusOverstay)
                }

                if let wallet = viewModel.wallet {
                    walletDetails(wallet: wallet)
                }

                Button("Refresh") {
                    Task {
                        await viewModel.loadWallet()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)
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
}
