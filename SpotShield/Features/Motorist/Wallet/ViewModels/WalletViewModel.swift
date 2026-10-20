//
//  WalletViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-18.
//

import Foundation
import Observation

@MainActor
@Observable
final class WalletViewModel {
    var wallet: Wallet?
    var transactions: [WalletTransaction] = []
    var isLoading = false
    var isAddingFunds = false
    var isUpdatingAutoDeduct = false
    var errorMessage = ""
    var historyErrorMessage = ""
    var successMessage = ""

    private let profile: UserProfile
    private let repository = WalletRepository()
    private let transactionRepository = WalletTransactionRepository()

    init(profile: UserProfile) {
        self.profile = profile
    }

    func loadWallet() async {
        guard !isLoading, !isAddingFunds, !isUpdatingAutoDeduct, !Task.isCancelled else {
            return
        }

        await refreshWallet(clearMessages: true)
    }

    private func refreshWallet(clearMessages: Bool) async {
        guard !isLoading, !Task.isCancelled else {
            return
        }

        if clearMessages {
            wallet = nil
            transactions = []
            errorMessage = ""
            historyErrorMessage = ""
            successMessage = ""
        }

        guard profile.role == .motorist else {
            errorMessage = "Wallets are available to Drivers only."
            return
        }

        isLoading = true

        defer {
            isLoading = false
        }

        do {
            try await repository.createWalletIfNeeded(
                userId: profile.id
            )

            guard !Task.isCancelled else { return }

            let savedWallet = try await repository.getWallet(
                userId: profile.id
            )

            guard !Task.isCancelled else { return }

            guard let savedWallet else {
                errorMessage = "Your wallet could not be found. Please try again."
                return
            }

            wallet = savedWallet

            await loadTransactions()
        } catch {
            guard !Task.isCancelled else { return }

            errorMessage = "Could not load your wallet. Please try again."
        }
    }

    private func loadTransactions() async {
        guard !Task.isCancelled else { return }

        do {
            let savedTransactions = try await transactionRepository
                .getTransactions(userId: profile.id)

            guard !Task.isCancelled else { return }

            transactions = savedTransactions
        } catch {
            guard !Task.isCancelled else { return }

            historyErrorMessage = "Could not load your transactions. Please refresh."
        }
    }

    func addDemoFunds() async {
        guard !isAddingFunds, !isLoading, !isUpdatingAutoDeduct else { return }

        errorMessage = ""
        successMessage = ""
        isAddingFunds = true

        defer {
            isAddingFunds = false
        }

        do {
            try await repository.addDemoFunds(userId: profile.id)
            successMessage = "LKR 1,000 demo funds added."
            await refreshWallet(clearMessages: false)
        } catch {
            errorMessage = "Could not confirm the top-up. Tap again to retry safely."
        }
    }

    func setTicketAutoDeduct(enabled: Bool) async {
        guard !isLoading, !isAddingFunds, !isUpdatingAutoDeduct,
              wallet != nil else { return }

        errorMessage = ""
        successMessage = ""
        isUpdatingAutoDeduct = true
        defer { isUpdatingAutoDeduct = false }

        do {
            try await repository.setTicketAutoDeduct(enabled: enabled)
            wallet?.autoDeductEnabled = enabled
            successMessage = enabled
                ? "Auto-deduction is on for new demo tickets."
                : "Auto-deduction is off."
        } catch {
            errorMessage = "Could not save this wallet setting. Refresh and try again."
        }
    }
}
